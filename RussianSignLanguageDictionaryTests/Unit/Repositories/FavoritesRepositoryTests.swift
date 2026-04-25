import Combine
import XCTest
@testable import RussianSignLanguageDictionary

final class FavoritesRepositoryTests: XCTestCase {
    private var sut: FavoritesRepository!
    private var userDefaults: UserDefaults!
    private var videoCacheService: MockVideoCacheService!

    override func setUp() {
        super.setUp()
        userDefaults = makeIsolatedUserDefaults()
        videoCacheService = MockVideoCacheService()
        sut = FavoritesRepository(
            userDefaults: userDefaults,
            videoCacheService: videoCacheService
        )
    }

    override func tearDown() {
        sut = nil
        userDefaults = nil
        videoCacheService = nil
        super.tearDown()
    }

    func testGetFavoritesInitiallyEmpty() {
        XCTAssertEqual(sut.getFavorites(), [])
        XCTAssertEqual(sut.getFavoriteEntries(), [])
    }

    func testAddFavoritePersistsWithoutDuplicatesAndPreservesInsertionOrder() {
        sut.addFavorite(signId: "sign-1")
        sut.addFavorite(signId: "sign-2")
        sut.addFavorite(signId: "sign-1")

        XCTAssertEqual(sut.getFavorites(), ["sign-1", "sign-2"])
        XCTAssertEqual(sut.getFavoriteEntries().map(\.signId), ["sign-1", "sign-2"])
    }

    func testAddFavoriteWithSnapshotPersistsSnapshotAndPendingStatus() {
        let sign = makeSign(id: "sign-1", videos: [makeVideo(id: 1)])

        sut.addFavorite(sign: sign, categoryName: "Категория 1")

        let entry = sut.getFavoriteEntry(signId: "sign-1")
        XCTAssertEqual(entry?.snapshot?.sign, sign)
        XCTAssertEqual(entry?.snapshot?.categoryName, "Категория 1")
        XCTAssertEqual(entry?.offlineStatus, .pending)
    }

    func testUpdateOfflineStatusPersistsAcrossRepositoryInstances() {
        sut.addFavorite(sign: makeSign(id: "sign-1", videos: [makeVideo(id: 1), makeVideo(id: 2)]), categoryName: "Категория 1")
        sut.updateOfflineStatus(
            signId: "sign-1",
            status: .readyOffline,
            downloadedVideoIds: [1, 2],
            requiredVideoIds: [1, 2]
        )

        let secondRepository = FavoritesRepository(
            userDefaults: userDefaults,
            videoCacheService: videoCacheService
        )

        let entry = secondRepository.getFavoriteEntry(signId: "sign-1")
        XCTAssertEqual(entry?.offlineStatus, .readyOffline)
        XCTAssertEqual(entry?.downloadedVideos.map(\.videoId), [1, 2])
        XCTAssertEqual(entry?.requiredVideoIds, [1, 2])
    }

    func testLegacyFavoriteIdsMigrateIntoFavoriteEntries() {
        let legacyDefaults = makeIsolatedUserDefaults()
        legacyDefaults.set(["sign-1", "sign-2"], forKey: "com.rsl.favorites")

        let migratedRepository = FavoritesRepository(
            userDefaults: legacyDefaults,
            videoCacheService: videoCacheService
        )

        let entries = migratedRepository.getFavoriteEntries()
        XCTAssertEqual(entries.map(\.signId), ["sign-1", "sign-2"])
        XCTAssertEqual(entries.map(\.offlineStatus), [.pending, .pending])
    }

    func testRemoveFavoriteClearsCachedVideosUsingStoredSnapshot() {
        let videos = [makeVideo(id: 1), makeVideo(id: 2)]
        sut.addFavorite(sign: makeSign(id: "sign-1", videos: videos), categoryName: "Категория 1")

        sut.removeFavorite(signId: "sign-1")

        XCTAssertEqual(videoCacheService.clearCacheCallCount, 1)
        XCTAssertFalse(sut.isFavorite(signId: "sign-1"))
    }

    func testClearAllFavoritesRemovesPersistedDataAndClearsVideoCache() {
        sut.addFavorite(signId: "sign-1")
        sut.addFavorite(signId: "sign-2")

        sut.clearAllFavorites()

        XCTAssertEqual(sut.getFavorites(), [])
        XCTAssertEqual(videoCacheService.clearAllCacheCallCount, 1)
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

    func testBackgroundThreadAddFavoriteMarshalsToMainThread() async {
        let completed = expectation(description: "favorite added on main thread")
        let cancellable = sut.$favoritesPublisher.sink { favorites in
            if favorites == ["sign-1"] {
                completed.fulfill()
            }
        }

        let repository = sut!
        await runOffMainThread {
            repository.addFavorite(signId: "sign-1")
        }

        await fulfillment(of: [completed], timeout: 1.0)
        cancellable.cancel()
        XCTAssertTrue(self.sut.isFavorite(signId: "sign-1"))
    }

    func testBackgroundThreadRemoveFavoriteMarshalsToMainThread() async {
        sut.addFavorite(signId: "sign-1")
        let completed = expectation(description: "favorite removed on main thread")
        let cancellable = sut.$favoritesPublisher.sink { favorites in
            if favorites.isEmpty {
                completed.fulfill()
            }
        }

        let repository = sut!
        await runOffMainThread {
            repository.removeFavorite(signId: "sign-1")
        }

        await fulfillment(of: [completed], timeout: 1.0)
        cancellable.cancel()
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

    private func runOffMainThread(_ work: @escaping () -> Void) async {
        let queue = DispatchQueue(label: "FavoritesRepositoryTests.background")
        await withCheckedContinuation { continuation in
            queue.async {
                work()
                continuation.resume()
            }
        }
    }
}
