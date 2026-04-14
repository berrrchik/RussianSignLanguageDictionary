import XCTest
@testable import RussianSignLanguageDictionary

final class SyncRepositoryTests: XCTestCase {
    private var sut: SyncRepository!
    private var etagManager: ETagManager!
    private var userDefaults: UserDefaults!
    private var controller: MockURLProtocol.SessionController!

    override func setUp() {
        super.setUp()
        userDefaults = makeIsolatedUserDefaults()
        etagManager = ETagManager(userDefaults: userDefaults)
        controller = MockURLProtocol.makeSessionController()
        sut = SyncRepository(
            baseURL: URL(string: "https://example.com")!,
            session: MockURLProtocol.makeEphemeralSession(controller: controller),
            etagManager: etagManager
        )
        controller.reset()
    }

    override func tearDown() {
        controller.reset()
        controller = nil
        sut = nil
        etagManager = nil
        userDefaults = nil
        super.tearDown()
    }

    func testCheckForUpdates200DecodesMetadata() async throws {
        let expectedDate = Date(timeIntervalSince1970: 1_700_000_000)
        controller.setRequestHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "If-None-Match"), nil)

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            let body = #"{"last_updated":1700000000,"has_updates":true}"#.data(using: .utf8)!
            return (response, body)
        }

        let metadata = try await sut.checkForUpdates(lastUpdated: nil)

        XCTAssertEqual(metadata.lastUpdated, expectedDate)
        XCTAssertTrue(metadata.hasUpdates)
    }

    func testFetchAllData200SavesETag() async throws {
        controller.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["ETag": #""1234567890abcdef1234567890abcdef:gzip""#]
            )!

            return (response, try self.makeSyncDataPayload())
        }

        _ = try await sut.fetchAllData {
            XCTFail("cachedDataProvider should not be used for 200")
            return TestFixtures.syncData
        }

        XCTAssertEqual(
            etagManager.getETag(for: .syncData),
            "1234567890abcdef1234567890abcdef"
        )
    }

    func testFetchAllData304ReturnsCachedData() async throws {
        controller.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 304,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data())
        }

        let syncData = try await sut.fetchAllData {
            TestFixtures.syncData
        }

        XCTAssertEqual(syncData.signs.count, TestFixtures.syncData.signs.count)
        XCTAssertEqual(syncData.lastUpdated, TestFixtures.syncData.lastUpdated)
    }

    func testFetchAllData304PropagatesCachedDataProviderError() async {
        controller.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 304,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data())
        }

        do {
            _ = try await sut.fetchAllData {
                throw SignRepositoryError.noDataAvailable
            }
            XCTFail("Expected cachedDataProvider error")
        } catch let error as SignRepositoryError {
            XCTAssertEqual(error, .noDataAvailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchAllDataSendsIfNoneMatchHeaderWhenETagExists() async throws {
        etagManager.saveETag(#""abcdefabcdefabcdefabcdefabcdef12""#, for: .syncData)

        controller.setRequestHandler { request in
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "If-None-Match"),
                "abcdefabcdefabcdefabcdefabcdef12"
            )

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 304,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data())
        }

        _ = try await sut.fetchAllData {
            TestFixtures.syncData
        }
    }

    func testCheckForUpdatesMapsURLErrorToSyncError() async {
        controller.setRequestHandler { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await sut.checkForUpdates(lastUpdated: nil)
            XCTFail("Expected noInternet")
        } catch let error as SyncError {
            guard case .noInternet = error else {
                return XCTFail("Expected noInternet, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchAllDataReturnsDecodingErrorForInvalidJSON() async {
        controller.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data("invalid-json".utf8))
        }

        do {
            _ = try await sut.fetchAllData {
                TestFixtures.syncData
            }
            XCTFail("Expected decodingError")
        } catch let error as SyncError {
            guard case .decodingError = error else {
                return XCTFail("Expected decodingError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCheckForUpdatesReturnsInvalidResponseForNonHTTPResponse() async {
        controller.setGenericRequestHandler { request in
            let response = URLResponse(
                url: try XCTUnwrap(request.url),
                mimeType: "application/json",
                expectedContentLength: 0,
                textEncodingName: nil
            )

            return (response, Data())
        }

        do {
            _ = try await sut.checkForUpdates(lastUpdated: nil)
            XCTFail("Expected invalidResponse")
        } catch let error as SyncError {
            guard case .invalidResponse = error else {
                return XCTFail("Expected invalidResponse, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCheckForUpdatesReturnsServerErrorForUnexpectedStatusCode() async {
        controller.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data())
        }

        do {
            _ = try await sut.checkForUpdates(lastUpdated: nil)
            XCTFail("Expected serverError")
        } catch let error as SyncError {
            guard case .serverError(let code) = error else {
                return XCTFail("Expected serverError, got \(error)")
            }
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeSyncDataPayload() throws -> Data {
        try APIJSONEncoder.shared.encode(TestFixtures.syncData)
    }
}
