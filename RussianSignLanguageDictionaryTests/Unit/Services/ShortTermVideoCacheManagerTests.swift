import XCTest
@testable import RussianSignLanguageDictionary

final class ShortTermVideoCacheManagerTests: XCTestCase {
    private var sut: ShortTermVideoCacheManager!
    private var networkMonitor: MockNetworkMonitor!
    private var tempDirectory: URL!
    private var session: URLSession!
    private var controller: MockURLProtocol.SessionController!
    private var requestCount: Int = 0
    private var onLRUInvocation: (() -> Void)?

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = try createTemporaryDirectory()
        networkMonitor = MockNetworkMonitor()
        networkMonitor.setConnected(true)
        controller = MockURLProtocol.makeSessionController()
        session = MockURLProtocol.makeEphemeralSession(controller: controller)
        requestCount = 0
        onLRUInvocation = nil
        controller.reset()
        sut = ShortTermVideoCacheManager(
            networkMonitor: networkMonitor,
            session: session,
            cacheDirectory: tempDirectory,
            cacheLimitEnforcer: { [weak self] _, _, _ in
                self?.onLRUInvocation?()
                return 0
            }
        )
    }

    override func tearDown() {
        controller.reset()
        controller = nil
        sut = nil
        networkMonitor = nil
        session = nil
        tempDirectory = nil
        onLRUInvocation = nil
        super.tearDown()
    }

    // MARK: - cachedVideoURL

    func testCachedVideoURLReturnsDiskFileAndUpdatesModificationDate() throws {
        let video = makeVideo(id: 1)
        let fileURL = tempDirectory.appendingPathComponent("video_1.mp4")
        try Data("video".utf8).write(to: fileURL)
        let oldDate = Date(timeIntervalSince1970: 10)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: fileURL.path)

        let cachedURL = sut.cachedVideoURL(for: video)

        XCTAssertEqual(cachedURL, fileURL)
        let newDate = try XCTUnwrap(
            fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        )
        XCTAssertGreaterThan(newDate, oldDate)
    }

    func testCachedVideoURLReturnsCachedURLOnSecondHit() throws {
        let video = makeVideo(id: 2)
        let fileURL = tempDirectory.appendingPathComponent("video_2.mp4")
        try Data("data".utf8).write(to: fileURL)

        // First access populates in-memory cache
        let first = sut.cachedVideoURL(for: video)
        // Second access should hit NSCache (same result)
        let second = sut.cachedVideoURL(for: video)

        XCTAssertEqual(first, fileURL)
        XCTAssertEqual(second, fileURL)
    }

    func testCachedVideoURLReturnsNilWhenFileAbsent() {
        let video = makeVideo(id: 99)
        XCTAssertNil(sut.cachedVideoURL(for: video))
    }

    // MARK: - downloadVideo

    func testDownloadVideoStoresFileInCacheDirectoryAndReturnsLocalURL() async throws {
        configureDownloadResponse(data: Data("video-bytes".utf8))
        let video = makeVideo(id: 1)
        let url = try XCTUnwrap(APIConfig.videoURL(forPath: video.url))

        let result = try await sut.downloadVideo(url: url, video: video)

        XCTAssertTrue(result.isFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.path))
        XCTAssertEqual(requestCount, 1)
    }

    func testDownloadVideoReusesCachedFileOnSecondRequest() async throws {
        configureDownloadResponse(data: Data("video-data".utf8))
        let video = makeVideo(id: 1)
        let url = try XCTUnwrap(APIConfig.videoURL(forPath: video.url))

        let first = try await sut.downloadVideo(url: url, video: video)
        let second = try await sut.downloadVideo(url: url, video: video)

        XCTAssertEqual(first, second)
        XCTAssertEqual(requestCount, 1)
    }

    func testDownloadVideoDeduplicatesParallelRequestsForSameId() async throws {
        let requestStarted = expectation(description: "request started")
        let releaseRequest = expectation(description: "release request")
        releaseRequest.assertForOverFulfill = false
        controller.setRequestHandler { request in
            self.requestCount += 1
            requestStarted.fulfill()
            self.wait(for: [releaseRequest], timeout: 1.0)
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("video-data".utf8))
        }
        let video = makeVideo(id: 1)
        let url = try XCTUnwrap(APIConfig.videoURL(forPath: video.url))

        let first = Task { try await self.sut.downloadVideo(url: url, video: video) }
        await fulfillment(of: [requestStarted], timeout: 1.0)
        let second = Task { try await self.sut.downloadVideo(url: url, video: video) }
        releaseRequest.fulfill()

        let results = try await [first.value, second.value]

        XCTAssertEqual(results[0], results[1])
        XCTAssertEqual(requestCount, 1)
    }

    func testDownloadVideoSkipsNetworkWhenFileExistsOnDisk() async throws {
        let video = makeVideo(id: 1)
        let url = try XCTUnwrap(APIConfig.videoURL(forPath: video.url))
        let fileURL = tempDirectory.appendingPathComponent("video_1.mp4")
        try Data("cached".utf8).write(to: fileURL)
        networkMonitor.setConnected(false)

        let result = try await sut.downloadVideo(url: url, video: video)

        XCTAssertEqual(result, fileURL)
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(networkMonitor.checkConnectionCallCount, 0)
    }

    func testDownloadVideoThrowsNoInternetWhenOfflineAndNoCacheHit() async throws {
        networkMonitor.setConnected(false)
        let video = makeVideo(id: 1)
        let url = try XCTUnwrap(APIConfig.videoURL(forPath: video.url))

        do {
            _ = try await sut.downloadVideo(url: url, video: video)
            XCTFail("Expected noInternetConnection error")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, .noInternetConnection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDownloadVideoMapsTimeoutErrorToVideoUnavailable() async throws {
        controller.setRequestHandler { request in
            self.requestCount += 1
            throw URLError(.timedOut, userInfo: [NSURLErrorKey: try XCTUnwrap(request.url)])
        }
        let video = makeVideo(id: 1)
        let url = try XCTUnwrap(APIConfig.videoURL(forPath: video.url))

        do {
            _ = try await sut.downloadVideo(url: url, video: video)
            XCTFail("Expected videoUnavailable error")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, .videoUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDownloadVideoTriggersLRUCleanupAfterStore() async throws {
        let lruExpectation = expectation(description: "LRU cleanup invoked")
        lruExpectation.assertForOverFulfill = false
        onLRUInvocation = { lruExpectation.fulfill() }
        configureDownloadResponse(data: Data("video-data".utf8))
        let video = makeVideo(id: 1)
        let url = try XCTUnwrap(APIConfig.videoURL(forPath: video.url))

        _ = try await sut.downloadVideo(url: url, video: video)

        await fulfillment(of: [lruExpectation], timeout: 1.0)
    }

    // MARK: - clear

    func testClearRemovesAllCachedFiles() async throws {
        configureDownloadResponse(data: Data("video-data".utf8))
        let video = makeVideo(id: 1)
        let url = try XCTUnwrap(APIConfig.videoURL(forPath: video.url))
        _ = try await sut.downloadVideo(url: url, video: video)
        XCTAssertNotNil(sut.cachedVideoURL(for: video))

        sut.clear()

        XCTAssertNil(sut.cachedVideoURL(for: video))
        let contents = try FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        )
        XCTAssertTrue(contents.isEmpty)
    }

    // MARK: - Helpers

    private func configureDownloadResponse(data: Data) {
        controller.setRequestHandler { request in
            self.requestCount += 1
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }
    }

    private func makeVideo(id: Int) -> SignVideo {
        SignVideo(
            id: id,
            url: "/signs/test/video_\(id).mp4",
            contextDescription: "Video \(id)",
            order: 1,
            createdAt: nil,
            updatedAt: nil
        )
    }
}
