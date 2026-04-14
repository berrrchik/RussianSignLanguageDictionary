import XCTest
@testable import RussianSignLanguageDictionary

final class FavoritesRepositoryTests: XCTestCase {
    private var sut: FavoritesRepository!
    private var userDefaults: UserDefaults!
    private var signRepository: MockSignRepository!
    private var videoCacheService: MockVideoCacheService!

    override func setUp() {
        super.setUp()
        userDefaults = makeIsolatedUserDefaults()
        signRepository = MockSignRepository()
        videoCacheService = MockVideoCacheService()
        sut = FavoritesRepository(
            userDefaults: userDefaults,
            signRepository: signRepository,
            videoCacheService: videoCacheService
        )
    }

    override func tearDown() {
        sut = nil
        userDefaults = nil
        signRepository = nil
        videoCacheService = nil
        super.tearDown()
    }

    func testGetFavoritesInitiallyEmpty() {
        XCTAssertEqual(sut.getFavorites(), [])
    }

    func testAddFavoritePersistsWithoutDuplicatesAndPreservesInsertionOrder() {
        sut.addFavorite(signId: "sign-1")
        sut.addFavorite(signId: "sign-2")
        sut.addFavorite(signId: "sign-1")

        XCTAssertEqual(sut.getFavorites(), ["sign-1", "sign-2"])
    }

    func testRemoveFavoriteRemovesOnlyRequestedId() {
        sut.addFavorite(signId: "sign-1")
        sut.addFavorite(signId: "sign-2")

        sut.removeFavorite(signId: "sign-1")

        XCTAssertEqual(sut.getFavorites(), ["sign-2"])
        XCTAssertFalse(sut.isFavorite(signId: "sign-1"))
    }

    func testClearAllFavoritesRemovesPersistedDataAndClearsVideoCache() {
        sut.addFavorite(signId: "sign-1")
        sut.addFavorite(signId: "sign-2")

        sut.clearAllFavorites()

        XCTAssertEqual(sut.getFavorites(), [])
        XCTAssertEqual(videoCacheService.clearAllCacheCallCount, 1)
    }

    func testFavoritesPersistAcrossRepositoryInstances() {
        sut.addFavorite(signId: "sign-1")

        let secondRepository = FavoritesRepository(
            userDefaults: userDefaults,
            signRepository: signRepository,
            videoCacheService: videoCacheService
        )

        XCTAssertEqual(secondRepository.getFavorites(), ["sign-1"])
    }

    func testFavoritesPublisherEmitsUpdatedFavorites() async {
        let expected = expectation(description: "favorites publisher updated")
        let cancellable = sut.$favoritesPublisher.sink { favorites in
            if favorites == ["sign-1"] {
                expected.fulfill()
            }
        }

        sut.addFavorite(signId: "sign-1")

        await fulfillment(of: [expected], timeout: 1.0)
        cancellable.cancel()
    }

    func testAddFavoritePreloadsVideosWhenSignExists() async {
        signRepository.mockSigns = [makeSign(id: "sign-1", videos: [makeVideo(id: 1), makeVideo(id: 2)])]

        sut.addFavorite(signId: "sign-1")

        let preloaded = await waitUntil {
            self.videoCacheService.preloadVideoCallCount == 2
        }
        XCTAssertTrue(preloaded)
        XCTAssertEqual(videoCacheService.lastPreloadedVideos.map(\.id), [1, 2])
    }

    func testAddFavoriteSkipsPreloadWhenSignMissing() async {
        signRepository.mockSigns = []

        sut.addFavorite(signId: "missing-sign")

        let noPreload = await waitUntil {
            self.videoCacheService.preloadVideoCallCount == 0
        }
        XCTAssertTrue(noPreload)
    }

    func testAddFavoriteSkipsPreloadWhenSignHasNoVideos() async {
        signRepository.mockSigns = [makeSign(id: "sign-1", videos: nil)]

        sut.addFavorite(signId: "sign-1")

        let noPreload = await waitUntil {
            self.videoCacheService.preloadVideoCallCount == 0
        }
        XCTAssertTrue(noPreload)
    }

    func testRemoveFavoriteClearsCachedVideosForKnownSign() async {
        let videos = [makeVideo(id: 1), makeVideo(id: 2)]
        signRepository.mockSigns = [makeSign(id: "sign-1", videos: videos)]
        sut.addFavorite(signId: "sign-1")

        sut.removeFavorite(signId: "sign-1")

        let cleared = await waitUntil {
            self.videoCacheService.clearCacheCallCount > 0
        }
        XCTAssertTrue(cleared)
    }

    func testRemoveFavoriteDoesNotClearCacheWhenSignMissing() async {
        signRepository.mockSigns = []

        sut.removeFavorite(signId: "sign-1")

        let noCleanup = await waitUntil {
            self.videoCacheService.clearCacheCallCount == 0
        }
        XCTAssertTrue(noCleanup)
    }

    func testBackgroundThreadAddFavoriteMarshalsToMainThread() async {
        let completed = expectation(description: "background add completed")
        let sut = self.sut!

        DispatchQueue.global().async {
            sut.addFavorite(signId: "sign-1")
            completed.fulfill()
        }

        await fulfillment(of: [completed], timeout: 1.0)
        XCTAssertTrue(self.sut.isFavorite(signId: "sign-1"))
    }

    func testBackgroundThreadRemoveFavoriteMarshalsToMainThread() async {
        sut.addFavorite(signId: "sign-1")
        let completed = expectation(description: "background remove completed")
        let sut = self.sut!

        DispatchQueue.global().async {
            sut.removeFavorite(signId: "sign-1")
            completed.fulfill()
        }

        await fulfillment(of: [completed], timeout: 1.0)
        XCTAssertFalse(self.sut.isFavorite(signId: "sign-1"))
    }

    private func makeSign(id: String, videos: [SignVideo]?) -> Sign {
        Sign(
            id: id,
            word: "Word \(id)",
            description: "Description",
            categoryId: "category-1",
            videos: videos,
            synonyms: nil
        )
    }

    private func makeVideo(id: Int) -> SignVideo {
        SignVideo(
            id: id,
            url: "/signs/test/video_\(id).mp4",
            contextDescription: "Video \(id)",
            order: id,
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
