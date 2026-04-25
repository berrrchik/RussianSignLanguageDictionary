import XCTest
@testable import RussianSignLanguageDictionary

final class VideoRepositoryOfflineTests: XCTestCase {
    private var sut: VideoRepository!
    private var networkMonitor: MockNetworkMonitor!
    private var videoCacheService: MockVideoCacheService!
    private var tempDirectory: URL!
    private var controller: MockURLProtocol.SessionController!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = try createTemporaryDirectory()
        networkMonitor = MockNetworkMonitor()
        videoCacheService = MockVideoCacheService()
        controller = MockURLProtocol.makeSessionController()
        sut = VideoRepository(
            videoCacheService: videoCacheService,
            networkMonitor: networkMonitor,
            session: MockURLProtocol.makeEphemeralSession(controller: controller),
            shortTermCacheDirectory: tempDirectory
        )
        controller.reset()
    }

    override func tearDown() {
        controller.reset()
        controller = nil
        sut = nil
        networkMonitor = nil
        videoCacheService = nil
        tempDirectory = nil
        super.tearDown()
    }

    func testGetVideoURLWithoutInternetForShortTermCacheThrowsError() async {
        networkMonitor.simulateNoInternet()

        do {
            _ = try await sut.getVideoURL(for: makeVideo(), useFavoritesCache: false)
            XCTFail("Expected no internet error")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, .noInternetConnection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetVideoURLWithoutInternetForFavoritesCacheSucceedsWhenCached() async throws {
        let video = makeVideo()
        let cachedURL = URL(fileURLWithPath: "/tmp/favorites-video.mp4")
        videoCacheService.addToCache(video: video, localURL: cachedURL)
        networkMonitor.simulateNoInternet()

        let url = try await sut.getVideoURL(for: video, useFavoritesCache: true)

        XCTAssertEqual(url, cachedURL)
    }

    func testGetVideoURLWithoutInternetForFavoritesCacheThrowsWhenNotCached() async {
        networkMonitor.simulateNoInternet()

        do {
            _ = try await sut.getVideoURL(for: makeVideo(), useFavoritesCache: true)
            XCTFail("Expected no internet error")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, .noInternetConnection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetLessonVideoURLWithoutInternetThrowsNoInternetConnection() async {
        networkMonitor.simulateNoInternet()
        let lesson = Lesson(
            id: "lesson-1",
            title: "Lesson",
            description: "Description",
            videoUrl: "/lessons/lesson.mp4",
            order: 1,
            createdAt: nil,
            updatedAt: nil
        )

        do {
            _ = try await sut.getVideoURL(for: lesson)
            XCTFail("Expected no internet error")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, .noInternetConnection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeVideo() -> SignVideo {
        SignVideo(
            id: 1,
            url: "/signs/test/video_1.mp4",
            contextDescription: "Video",
            order: 1,
            createdAt: nil,
            updatedAt: nil
        )
    }
}
