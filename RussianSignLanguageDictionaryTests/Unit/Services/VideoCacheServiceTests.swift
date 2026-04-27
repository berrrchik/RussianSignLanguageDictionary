import XCTest
@testable import RussianSignLanguageDictionary

final class VideoCacheServiceTests: XCTestCase {
    private var sut: VideoCacheService!
    private var tempDirectory: URL!
    private var controller: MockURLProtocol.SessionController!
    private var networkMonitor: MockNetworkMonitor!
    private var directoryManager: VideoCacheDirectoryManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = try createTemporaryDirectory()
        networkMonitor = MockNetworkMonitor()
        networkMonitor.setConnected(true)
        controller = MockURLProtocol.makeSessionController()
        let manager = VideoCacheDirectoryManager(cacheDirectory: tempDirectory)
        directoryManager = manager
        let downloader = VideoCacheDownloader(
            directoryManager: manager,
            networkMonitor: networkMonitor,
            session: MockURLProtocol.makeEphemeralSession(controller: controller)
        )
        sut = VideoCacheService(
            directoryManager: manager,
            downloader: downloader,
            networkMonitor: networkMonitor
        )
        controller.reset()
    }

    override func tearDown() {
        controller.reset()
        controller = nil
        directoryManager = nil
        networkMonitor = nil
        sut = nil
        tempDirectory = nil
        super.tearDown()
    }

    func testIsVideoCachedReturnsFalseForInvalidURL() {
        XCTAssertFalse(sut.isVideoCached(makeVideo(url: "")))
        XCTAssertNil(sut.getCachedVideoURL(makeVideo(url: "")))
    }

    func testDownloadAndCacheStoresVideoForLookupByModelAndURL() async throws {
        let video = makeVideo()
        controller.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("video-data".utf8))
        }

        let localURL = try await sut.downloadAndCache(video: video)

        XCTAssertTrue(localURL.isFileURL)
        XCTAssertTrue(sut.isVideoCached(video))
        XCTAssertTrue(sut.isVideoCached(url: try XCTUnwrap(APIConfig.videoURL(forPath: video.url))))
        XCTAssertEqual(sut.getCachedVideoURL(video), localURL)
    }

    func testGetCachedVideoURLReturnsNilForMissingVideo() {
        XCTAssertNil(sut.getCachedVideoURL(makeVideo()))
        XCTAssertNil(sut.getCachedVideoURL(originalURL: URL(string: "https://example.com/missing.mp4")!))
    }

    func testClearCacheForSignRemovesAllCachedVideos() async throws {
        let first = makeVideo(id: 1, url: "/signs/test/one.mp4")
        let second = makeVideo(id: 2, url: "/signs/test/two.mp4")
        controller.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data((request.url?.absoluteString ?? "").utf8))
        }

        _ = try await sut.downloadAndCache(video: first)
        _ = try await sut.downloadAndCache(video: second)

        sut.clearCache(for: "sign-1", videos: [first, second])

        let cleared = await waitUntil {
            !self.sut.isVideoCached(first) && !self.sut.isVideoCached(second)
        }
        XCTAssertTrue(cleared)
    }

    func testClearAllCacheRemovesDownloadedFiles() async throws {
        let video = makeVideo()
        controller.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("video-data".utf8))
        }

        _ = try await sut.downloadAndCache(video: video)
        sut.clearAllCache()

        let cleared = await waitUntil {
            !self.sut.isVideoCached(video) && self.sut.getCacheSize() == 0
        }
        XCTAssertTrue(cleared)
    }

    func testGetCacheSizeReflectsDownloadedBytes() async throws {
        controller.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(repeating: 0x41, count: 7))
        }

        _ = try await sut.downloadAndCache(video: makeVideo())

        XCTAssertGreaterThanOrEqual(sut.getCacheSize(), 7)
    }

    func testEnsureCacheLimitDoesNotCrashOnEmptyCache() {
        sut.ensureCacheLimit()
        XCTAssertEqual(sut.getCacheSize(), 0)
    }

    func testDownloadAndCacheFastFailsOfflineWithoutRequest() async {
        networkMonitor.simulateNoInternet()
        controller.setRequestHandler { _ in
            XCTFail("Network request should not start while offline")
            throw URLError(.badServerResponse)
        }

        do {
            _ = try await sut.downloadAndCache(video: makeVideo())
            XCTFail("Expected no internet error")
        } catch let error as VideoCacheError {
            XCTAssertEqual(error, .noInternetConnection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPromoteCachedVideoCopiesShortTermFileIntoDurableCache() throws {
        let video = makeVideo()
        let sourceURL = tempDirectory.appendingPathComponent("short-term.mp4")
        let sourceData = Data("video-data".utf8)
        try sourceData.write(to: sourceURL)

        let promotedURL = try sut.promoteCachedVideo(video, from: sourceURL)
        let originalURL = try XCTUnwrap(APIConfig.videoURL(forPath: video.url))
        let expectedURL = try XCTUnwrap(
            directoryManager.cacheFileURL(for: directoryManager.videoId(from: originalURL))
        )

        XCTAssertEqual(promotedURL, expectedURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: promotedURL.path))
        XCTAssertEqual(try Data(contentsOf: promotedURL), sourceData)
        XCTAssertEqual(sut.getCachedVideoURL(video), promotedURL)
    }

    func testPromoteCachedVideoThrowsInvalidURLForMalformedVideoPath() {
        XCTAssertThrowsError(
            try sut.promoteCachedVideo(makeVideo(url: ""), from: tempDirectory.appendingPathComponent("video.mp4"))
        ) { error in
            XCTAssertEqual(error as? VideoCacheError, .invalidURL)
        }
    }

    func testPromoteCachedVideoThrowsCacheDirectoryNotAvailableWhenManagerHasNoCacheDirectory() {
        let brokenManager = VideoCacheDirectoryManager(fileManager: UnavailableCachesFileManager())
        let brokenService = VideoCacheService(
            directoryManager: brokenManager,
            networkMonitor: networkMonitor
        )

        XCTAssertThrowsError(
            try brokenService.promoteCachedVideo(makeVideo(), from: tempDirectory.appendingPathComponent("video.mp4"))
        ) { error in
            XCTAssertEqual(error as? VideoCacheError, .cacheDirectoryNotAvailable)
        }
    }

    private func makeVideo(id: Int = 1, url: String = "/signs/test/video_1.mp4") -> SignVideo {
        SignVideo(
            id: id,
            url: url,
            contextDescription: "Video \(id)",
            order: 1,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollInterval: UInt64 = 20_000_000,
        condition: @escaping () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return true
            }

            try? await Task.sleep(nanoseconds: pollInterval)
        }

        return condition()
    }
}

private final class UnavailableCachesFileManager: FileManager {
    override func urls(for directory: SearchPathDirectory, in domainMask: SearchPathDomainMask) -> [URL] {
        []
    }
}
