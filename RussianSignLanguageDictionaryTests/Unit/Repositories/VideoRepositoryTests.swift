import XCTest
@testable import RussianSignLanguageDictionary

final class VideoRepositoryTests: XCTestCase {
    private var sut: VideoRepository!
    private var networkMonitor: MockNetworkMonitor!
    private var videoCacheService: MockVideoCacheService!
    private var tempDirectory: URL!
    private var session: URLSession!
    private var lruInvocationCount: Int = 0
    private var requestCount: Int = 0

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = try createTemporaryDirectory()
        networkMonitor = MockNetworkMonitor()
        networkMonitor.setConnected(true)
        videoCacheService = MockVideoCacheService()
        session = MockURLProtocol.makeEphemeralSession()
        lruInvocationCount = 0
        requestCount = 0
        MockURLProtocol.reset()
        sut = VideoRepository(
            videoCacheService: videoCacheService,
            networkMonitor: networkMonitor,
            session: session,
            shortTermCacheDirectory: tempDirectory,
            cacheLimitEnforcer: { _, _, _ in
                self.lruInvocationCount += 1
                return 0
            }
        )
        lruInvocationCount = 0
    }

    override func tearDown() {
        MockURLProtocol.reset()
        sut = nil
        networkMonitor = nil
        videoCacheService = nil
        session = nil
        tempDirectory = nil
        super.tearDown()
    }

    func testCachedVideoURLReturnsDiskFileAndTouchesModificationDate() async throws {
        let video = makeVideo(id: 1)
        let fileURL = tempDirectory.appendingPathComponent("video_1.mp4")
        try Data("video".utf8).write(to: fileURL)
        let oldDate = Date(timeIntervalSince1970: 10)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: fileURL.path)

        let cachedURL = sut.cachedVideoURL(for: video)

        XCTAssertEqual(cachedURL, fileURL)
        let newDate = try XCTUnwrap(fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        XCTAssertGreaterThan(newDate, oldDate)
    }

    func testCachedVideoURLFallsBackToFavoritesCache() {
        let video = makeVideo(id: 1)
        let favoritesURL = URL(fileURLWithPath: "/tmp/favorites-video.mp4")
        videoCacheService.addToCache(video: video, localURL: favoritesURL)

        XCTAssertEqual(sut.cachedVideoURL(for: video), favoritesURL)
    }

    func testGetVideoURLDownloadsToShortTermCacheAndReusesCachedFile() async throws {
        configureDownloadResponse(data: Data("video-data".utf8))
        let video = makeVideo(id: 1)

        let first = try await sut.getVideoURL(for: video, useFavoritesCache: false)
        let second = try await sut.getVideoURL(for: video, useFavoritesCache: false)

        XCTAssertEqual(first, second)
        XCTAssertTrue(first.isFileURL)
        XCTAssertEqual(requestCount, 1)
    }

    func testGetVideoURLParallelSameIdUsesSingleDownload() async throws {
        configureDownloadResponse(data: Data("video-data".utf8), delay: 0.2)
        let video = makeVideo(id: 1)

        async let first = sut.getVideoURL(for: video, useFavoritesCache: false)
        async let second = sut.getVideoURL(for: video, useFavoritesCache: false)

        let results = try await [first, second]

        XCTAssertEqual(results[0], results[1])
        XCTAssertEqual(requestCount, 1)
    }

    func testGetVideoURLWithoutInternetThrowsNoInternetConnection() async {
        networkMonitor.setConnected(false)

        do {
            _ = try await sut.getVideoURL(for: makeVideo(id: 1), useFavoritesCache: false)
            XCTFail("Expected no internet error")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, .noInternetConnection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetVideoURLWithFavoritesCacheUsesCachedVideoOffline() async throws {
        let video = makeVideo(id: 1)
        let favoritesURL = URL(fileURLWithPath: "/tmp/favorites-video.mp4")
        videoCacheService.addToCache(video: video, localURL: favoritesURL)
        networkMonitor.setConnected(false)

        let url = try await sut.getVideoURL(for: video, useFavoritesCache: true)

        XCTAssertEqual(url, favoritesURL)
    }

    func testGetVideoURLWithFavoritesCacheWithoutInternetAndWithoutCacheThrowsVideoNotCached() async {
        networkMonitor.setConnected(false)

        do {
            _ = try await sut.getVideoURL(for: makeVideo(id: 1), useFavoritesCache: true)
            XCTFail("Expected video not cached error")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, .videoNotCached)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPreloadVideoStoresShortTermCachedFile() async throws {
        configureDownloadResponse(data: Data("video-data".utf8))
        let sign = makeSign(video: makeVideo(id: 1))

        try await sut.preloadVideo(for: sign)

        XCTAssertNotNil(sut.cachedVideoURL(for: try XCTUnwrap(sign.videos?.first)))
    }

    func testClearCacheRemovesShortTermFiles() async throws {
        configureDownloadResponse(data: Data("video-data".utf8))
        let video = makeVideo(id: 1)
        _ = try await sut.getVideoURL(for: video, useFavoritesCache: false)

        sut.clearCache()

        XCTAssertNil(sut.cachedVideoURL(for: video))
    }

    func testGetVideoURLTriggersLRUCleanupAfterDownload() async throws {
        configureDownloadResponse(data: Data("video-data".utf8))

        _ = try await sut.getVideoURL(for: makeVideo(id: 1), useFavoritesCache: false)

        let lruTriggered = await waitUntil { self.lruInvocationCount > 0 }
        XCTAssertTrue(lruTriggered)
    }

    func testGetVideoURLWithInvalidVideoThrowsInvalidURL() async {
        do {
            _ = try await sut.getVideoURL(
                for: SignVideo(
                    id: 1,
                    url: "",
                    contextDescription: "",
                    order: 1,
                    createdAt: nil,
                    updatedAt: nil
                ),
                useFavoritesCache: false
            )
            XCTFail("Expected invalid URL")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, .invalidURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetVideoURLForSignWithoutVideosThrowsInvalidURL() async {
        do {
            _ = try await sut.getVideoURL(for: makeSign(video: nil))
            XCTFail("Expected invalid URL")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, .invalidURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func configureDownloadResponse(data: Data, delay: TimeInterval = 0) {
        MockURLProtocol.setRequestHandler { request in
            self.requestCount += 1
            if delay > 0 {
                Thread.sleep(forTimeInterval: delay)
            }

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

    private func makeSign(video: SignVideo?) -> Sign {
        Sign(
            id: "sign-1",
            word: "Word",
            description: "Description",
            categoryId: "category-1",
            videos: video.map { [$0] },
            synonyms: nil
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
