import XCTest
@testable import RussianSignLanguageDictionary

final class SBERTSearchServiceTests: XCTestCase {
    private var sut: SBERTSearchService!
    private var controller: MockURLProtocol.SessionController!

    override func setUp() {
        super.setUp()
        controller = MockURLProtocol.makeSessionController()
        sut = SBERTSearchService(
            baseURL: URL(string: "https://example.com")!,
            session: MockURLProtocol.makeEphemeralSession(controller: controller)
        )
        controller.reset()
    }

    override func tearDown() {
        controller.reset()
        controller = nil
        sut = nil
        super.tearDown()
    }

    func testSearchSuccessDecodesResults() async throws {
        controller.setRequestHandler { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/search/sbert")

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, self.makeSuccessResponse(results: [
                ["id": "sign-1", "word": "Привет", "similarity": 0.91]
            ]))
        }

        let results = try await sut.search(query: "привет", limit: 10, minSimilarity: 0.4)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, "sign-1")
        XCTAssertEqual(results.first?.similarity, 0.91)
    }

    func testSearchReturnsServerErrorWhenSuccessFalse() async {
        controller.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            let body = try JSONSerialization.data(withJSONObject: [
                "success": false,
                "error": [
                    "code": "SEARCH_DISABLED",
                    "message": "Search unavailable"
                ]
            ])
            return (response, body)
        }

        do {
            _ = try await sut.search(query: "привет", limit: 10, minSimilarity: 0.4)
            XCTFail("Expected serverError")
        } catch let error as SBERTSearchError {
            guard case .serverError(let code, let message) = error else {
                return XCTFail("Expected serverError, got \(error)")
            }
            XCTAssertEqual(code, "SEARCH_DISABLED")
            XCTAssertEqual(message, "Search unavailable")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSearchReturnsHTTPErrorForNon200Response() async {
        controller.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data("{}".utf8))
        }

        do {
            _ = try await sut.search(query: "привет", limit: 10, minSimilarity: 0.4)
            XCTFail("Expected httpError")
        } catch let error as SBERTSearchError {
            guard case .httpError(let statusCode) = error else {
                return XCTFail("Expected httpError, got \(error)")
            }
            XCTAssertEqual(statusCode, 503)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSearchMapsNetworkError() async {
        controller.setRequestHandler { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await sut.search(query: "привет", limit: 10, minSimilarity: 0.4)
            XCTFail("Expected httpError")
        } catch let error as SBERTSearchError {
            guard case .httpError(let statusCode) = error else {
                return XCTFail("Expected httpError, got \(error)")
            }
            XCTAssertEqual(statusCode, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSearchReturnsInvalidResponseForInvalidJSON() async {
        controller.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data("not-json".utf8))
        }

        do {
            _ = try await sut.search(query: "привет", limit: 10, minSimilarity: 0.4)
            XCTFail("Expected invalidResponse")
        } catch let error as SBERTSearchError {
            guard case .invalidResponse = error else {
                return XCTFail("Expected invalidResponse, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSearchRejectsEmptyQuery() async {
        do {
            _ = try await sut.search(query: "   ", limit: 10, minSimilarity: 0.4)
            XCTFail("Expected validation error")
        } catch let error as SBERTSearchError {
            guard case .serverError(let code, _) = error else {
                return XCTFail("Expected serverError, got \(error)")
            }
            XCTAssertEqual(code, "VALIDATION_ERROR")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSearchClampsLimitAndMinSimilarity() async throws {
        controller.setRequestHandler { request in
            let body = try self.requestBodyData(from: request)
            let bodyString = try XCTUnwrap(String(data: body, encoding: .utf8))

            XCTAssertTrue(bodyString.contains("\"limit\":50"))
            XCTAssertTrue(
                bodyString.contains("\"min_similarity\":1") ||
                bodyString.contains("\"min_similarity\":1.0")
            )

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, self.makeSuccessResponse(results: []))
        }

        let results = try await sut.search(query: "привет", limit: 500, minSimilarity: 2.0)

        XCTAssertTrue(results.isEmpty)
    }

    private func makeSuccessResponse(results: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "success": true,
            "data": [
                "query": "привет",
                "model": "test-model",
                "total_found": results.count,
                "results": results
            ]
        ])
    }

    private func requestBodyData(from request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            throw XCTSkip("Request body is unavailable")
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while stream.hasBytesAvailable {
            let readCount = stream.read(&buffer, maxLength: bufferSize)

            if readCount < 0, let streamError = stream.streamError {
                throw streamError
            }

            if readCount == 0 {
                break
            }

            data.append(buffer, count: readCount)
        }

        return data
    }
}
