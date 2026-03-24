import Foundation

final class MockURLProtocol: URLProtocol {
    typealias RequestHandler = (URLRequest) throws -> (HTTPURLResponse, Data)
    typealias GenericRequestHandler = (URLRequest) throws -> (URLResponse, Data)

    private static let lock = NSLock()
    private static var requestHandler: RequestHandler?
    private static var genericRequestHandler: GenericRequestHandler?

    static func setRequestHandler(_ handler: RequestHandler?) {
        lock.lock()
        requestHandler = handler
        genericRequestHandler = nil
        lock.unlock()
    }

    static func setGenericRequestHandler(_ handler: GenericRequestHandler?) {
        lock.lock()
        genericRequestHandler = handler
        requestHandler = nil
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        requestHandler = nil
        genericRequestHandler = nil
        lock.unlock()
    }

    static func makeEphemeralSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
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
        let handler = Self.requestHandler
        let genericHandler = Self.genericRequestHandler
        Self.lock.unlock()

        guard handler != nil || genericHandler != nil else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        do {
            let responseAndData: (URLResponse, Data)

            if let genericHandler {
                responseAndData = try genericHandler(request)
            } else if let handler {
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
