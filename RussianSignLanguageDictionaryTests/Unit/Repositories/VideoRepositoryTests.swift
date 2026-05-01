import XCTest
@testable import RussianSignLanguageDictionary

final class VideoRepositoryTests: XCTestCase {
    private var sut: VideoRepository!
    private var networkMonitor: MockNetworkMonitor!
    private var videoCacheService: MockVideoCacheService!
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
        videoCacheService = MockVideoCacheService()
        controller = MockURLProtocol.makeSessionController()
        session = MockURLProtocol.makeEphemeralSession(controller: controller)
        requestCount = 0
        onLRUInvocation = nil
        controller.reset()
        sut = VideoRepository(
            videoCacheService: videoCacheService,
            networkMonitor: networkMonitor,
            session: session,
            shortTermCacheDirectory: tempDirectory,
            cacheLimitEnforcer: { _, _, _ in
                self.onLRUInvocation?()
                return 0
            }
        )
    }

    override func tearDown() {
        controller.reset()
        controller = nil
        sut = nil
        networkMonitor = nil
        videoCacheService = nil
        session = nil
        tempDirectory = nil
        onLRUInvocation = nil
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

    func testGetVideoURLShortTermCacheHitWinsOverNetworkAndConnectivityCheck() async throws {
        let video = makeVideo(id: 1)
        let fileURL = tempDirectory.appendingPathComponent("video_1.mp4")
        try Data("cached".utf8).write(to: fileURL)
        networkMonitor.setConnected(false)

        let url = try await sut.getVideoURL(for: video, useFavoritesCache: false)

        XCTAssertEqual(url, fileURL)
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(networkMonitor.checkConnectionCallCount, 0)
    }

    func testGetVideoURLParallelSameIdUsesSingleDownload() async throws {
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

        let first = Task { try await self.sut.getVideoURL(for: video, useFavoritesCache: false) }
        await fulfillment(of: [requestStarted], timeout: 1.0)
        let second = Task { try await self.sut.getVideoURL(for: video, useFavoritesCache: false) }
        releaseRequest.fulfill()

        let results = try await [first.value, second.value]

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

        XCTAssertEqual(requestCount, 0)
    }

    func testGetVideoURLWithFavoritesCacheUsesCachedVideoOffline() async throws {
        let video = makeVideo(id: 1)
        let favoritesURL = URL(fileURLWithPath: "/tmp/favorites-video.mp4")
        videoCacheService.addToCache(video: video, localURL: favoritesURL)
        networkMonitor.setConnected(false)

        let url = try await sut.getVideoURL(for: video, useFavoritesCache: true)

        XCTAssertEqual(url, favoritesURL)
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(networkMonitor.checkConnectionCallCount, 0)
    }

    func testGetVideoURLWithFavoritesCachePromotesShortTermCachedFileWithoutNetwork() async throws {
        let video = makeVideo(id: 1)
        let shortTermURL = tempDirectory.appendingPathComponent("video_1.mp4")
        try Data("cached".utf8).write(to: shortTermURL)
        networkMonitor.setConnected(false)

        let url = try await sut.getVideoURL(for: video, useFavoritesCache: true)

        XCTAssertEqual(url, URL(fileURLWithPath: "/tmp/favorites_1.mp4"))
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(networkMonitor.checkConnectionCallCount, 0)
    }

    func testGetVideoURLWithFavoritesCacheWithoutInternetAndWithoutCacheThrowsNoInternetConnection() async {
        networkMonitor.setConnected(false)

        do {
            _ = try await sut.getVideoURL(for: makeVideo(id: 1), useFavoritesCache: true)
            XCTFail("Expected no internet error")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, .noInternetConnection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetVideoURLMapsServerTimeoutToVideoUnavailable() async {
        controller.setRequestHandler { request in
            self.requestCount += 1
            throw URLError(.timedOut, userInfo: [NSURLErrorKey: try XCTUnwrap(request.url)])
        }

        do {
            _ = try await sut.getVideoURL(for: makeVideo(id: 1), useFavoritesCache: false)
            XCTFail("Expected video unavailable error")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, .videoUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetLessonVideoURLReturnsRemoteURLWithoutPreflightRequest() async throws {
        let lesson = Lesson(
            id: "lesson-1",
            title: "Lesson",
            description: "Description",
            videoUrl: "/lessons/lesson.mp4",
            order: 1,
            createdAt: nil,
            updatedAt: nil
        )

        let url = try await sut.getVideoURL(for: lesson)

        XCTAssertEqual(url, try XCTUnwrap(APIConfig.videoURL(forPath: lesson.videoUrl)))
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(networkMonitor.checkConnectionCallCount, 1)
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
        let lruExpectation = expectation(description: "LRU cleanup invoked")
        lruExpectation.assertForOverFulfill = false
        onLRUInvocation = {
            lruExpectation.fulfill()
        }
        configureDownloadResponse(data: Data("video-data".utf8))

        _ = try await sut.getVideoURL(for: makeVideo(id: 1), useFavoritesCache: false)

        await fulfillment(of: [lruExpectation], timeout: 1.0)
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
}
