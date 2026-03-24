import Foundation
import XCTest

final class MockURLProtocolTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testEphemeralSessionUsesStubbedResponse() async throws {
        let expectedBody = #"{"status":"ok"}"#.data(using: .utf8)!
        MockURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/ping")

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            return (response, expectedBody)
        }

        let session = MockURLProtocol.makeEphemeralSession()
        let (data, response) = try await session.data(from: URL(string: "https://example.com/ping")!)

        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(data, expectedBody)
    }
}
