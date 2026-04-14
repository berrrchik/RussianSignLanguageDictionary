import Foundation

final class MockURLProtocol: URLProtocol {
    typealias RequestHandler = (URLRequest) throws -> (HTTPURLResponse, Data)
    typealias GenericRequestHandler = (URLRequest) throws -> (URLResponse, Data)

    final class SessionController {
        fileprivate let id = UUID().uuidString

        func setRequestHandler(_ handler: RequestHandler?) {
            MockURLProtocol.lock.lock()
            MockURLProtocol.handlersBySessionID[id] = Handlers(
                requestHandler: handler,
                genericRequestHandler: nil
            )
            MockURLProtocol.lock.unlock()
        }

        func setGenericRequestHandler(_ handler: GenericRequestHandler?) {
            MockURLProtocol.lock.lock()
            MockURLProtocol.handlersBySessionID[id] = Handlers(
                requestHandler: nil,
                genericRequestHandler: handler
            )
            MockURLProtocol.lock.unlock()
        }

        func reset() {
            MockURLProtocol.lock.lock()
            MockURLProtocol.handlersBySessionID.removeValue(forKey: id)
            MockURLProtocol.lock.unlock()
        }
    }

    private struct Handlers {
        let requestHandler: RequestHandler?
        let genericRequestHandler: GenericRequestHandler?
    }

    private static let sessionIDHeader = "X-MockURLProtocol-Session-ID"
    private static let defaultSessionID = "__default__"

    private static let lock = NSLock()
    private static var handlersBySessionID: [String: Handlers] = [:]

    static func makeSessionController() -> SessionController {
        SessionController()
    }

    static func setRequestHandler(_ handler: RequestHandler?) {
        lock.lock()
        handlersBySessionID[defaultSessionID] = Handlers(
            requestHandler: handler,
            genericRequestHandler: nil
        )
        lock.unlock()
    }

    static func setGenericRequestHandler(_ handler: GenericRequestHandler?) {
        lock.lock()
        handlersBySessionID[defaultSessionID] = Handlers(
            requestHandler: nil,
            genericRequestHandler: handler
        )
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        handlersBySessionID.removeAll()
        lock.unlock()
    }

    static func makeEphemeralSession() -> URLSession {
        let controller = makeSessionController()
        return makeEphemeralSession(controller: controller)
    }

    static func makeEphemeralSession(controller: SessionController) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        var headers = configuration.httpAdditionalHeaders ?? [:]
        headers[sessionIDHeader] = controller.id
        configuration.httpAdditionalHeaders = headers
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        let sessionID = request.value(forHTTPHeaderField: Self.sessionIDHeader) ?? Self.defaultSessionID
        let handlers = Self.handlersBySessionID[sessionID]
        Self.lock.unlock()

        guard let handlers else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        do {
            let responseAndData: (URLResponse, Data)

            if let genericHandler = handlers.genericRequestHandler {
                responseAndData = try genericHandler(request)
            } else if let handler = handlers.requestHandler {
                let (response, data) = try handler(request)
                responseAndData = (response, data)
            } else {
                client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
                return
            }

            let (response, data) = responseAndData
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !data.isEmpty {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
