import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class FavoritesViewModelTests: XCTestCase {
    private var sut: FavoritesViewModel!
    private var favoritesRepository: FavoritesRepositorySpy!
    private var signRepository: SignRepositorySpy!
    private var offlinePreparationService: OfflinePreparationServiceSpy!
    private var networkMonitor: NetworkMonitorSpy!

    override func setUp() {
        super.setUp()
        favoritesRepository = FavoritesRepositorySpy()
        signRepository = SignRepositorySpy()
        offlinePreparationService = OfflinePreparationServiceSpy()
        networkMonitor = NetworkMonitorSpy()
        sut = FavoritesViewModel(
            favoritesRepository: favoritesRepository,
            signRepository: signRepository,
            offlinePreparationService: offlinePreparationService,
            networkMonitor: networkMonitor
        )
    }

    override func tearDown() {
        sut = nil
        favoritesRepository = nil
        signRepository = nil
        offlinePreparationService = nil
        networkMonitor = nil
        super.tearDown()
    }

    func testLoadFavoritesLoadsSignsInFavoritesOrderAndStoresSnapshots() async {
        favoritesRepository.entries = [
            FavoriteEntry(signId: "sign-2"),
            FavoriteEntry(signId: "sign-1")
        ]
        signRepository.loadAllSignsResult = .success([
            makeSign(id: "sign-1", word: "Буква"),
            makeSign(id: "sign-2", word: "Арбуз")
        ])
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-1", name: "Категория 1", order: 1)
        ])

        await sut.loadFavorites()

        XCTAssertEqual(sut.favoriteSigns.map(\.id), ["sign-2", "sign-1"])
        XCTAssertEqual(sut.categoryNamesById["category-1"], "Категория 1")
        XCTAssertEqual(favoritesRepository.updateFavoriteSnapshotCalls.count, 2)
        XCTAssertEqual(favoritesRepository.reconcileOfflineStateCallCount, 1)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadFavoritesFallsBackToCachedSnapshotsWhenMainLoadFails() async {
        favoritesRepository.entries = [
            FavoriteEntry(
                signId: "sign-1",
                snapshot: FavoriteSignSnapshot(sign: makeSign(id: "sign-1", word: "Привет"), categoryName: "Категория 1"),
                offlineStatus: .readyOffline
            )
        ]
        signRepository.loadAllSignsResult = .failure(SignRepositoryError.noDataAvailable)

        await sut.loadFavorites()

        XCTAssertEqual(sut.favoriteSigns.map(\.id), ["sign-1"])
        XCTAssertEqual(sut.offlineStatus(for: "sign-1"), .readyOffline)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadFavoritesKeepsMissingLiveSignsWhenSnapshotExists() async {
        favoritesRepository.entries = [
            FavoriteEntry(
                signId: "sign-1",
                snapshot: FavoriteSignSnapshot(sign: makeSign(id: "sign-1", word: "Привет"), categoryName: "Категория 1"),
                offlineStatus: .failed
            ),
            FavoriteEntry(signId: "sign-2", offlineStatus: .pending)
        ]
        signRepository.loadAllSignsResult = .success([
            makeSign(id: "sign-2", word: "Пока")
        ])
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-1", name: "Категория 1", order: 1)
        ])

        await sut.loadFavorites()

        XCTAssertEqual(sut.favoriteSigns.map(\.id), ["sign-2", "sign-1"])
        XCTAssertEqual(sut.offlineStatus(for: "sign-1"), .failed)
        XCTAssertEqual(sut.offlineStatus(for: "sign-2"), .pending)
        XCTAssertNil(sut.errorMessage)
        XCTAssertTrue(favoritesRepository.removeFavoriteCalls.isEmpty)
    }

    func testLoadFavoritesReturnsEmptyStateWhenFavoritesListIsEmpty() async {
        favoritesRepository.entries = []

        await sut.loadFavorites()

        XCTAssertEqual(sut.favoriteSigns, [])
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(signRepository.loadAllSignsCallCount, 0)
    }

    func testLoadFavoritesMapsRepositoryErrorWhenNoSnapshotsExist() async {
        favoritesRepository.entries = [FavoriteEntry(signId: "sign-1")]
        signRepository.loadAllSignsResult = .failure(SignRepositoryError.noDataAvailable)

        await sut.loadFavorites()

        XCTAssertEqual(
            sut.errorMessage,
            "Данные недоступны. Повторите попытку позже."
        )
        XCTAssertFalse(sut.isLoading)
    }

    func testRemoveFavoriteUpdatesRepositoryAndState() async {
        favoritesRepository.entries = [
            FavoriteEntry(signId: "sign-1"),
            FavoriteEntry(signId: "sign-2")
        ]
        signRepository.loadAllSignsResult = .success([
            makeSign(id: "sign-1", word: "Привет"),
            makeSign(id: "sign-2", word: "Пока")
        ])
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-1", name: "Категория 1", order: 1)
        ])

        await sut.loadFavorites()

        sut.removeFavorite(signId: "sign-1")

        XCTAssertEqual(favoritesRepository.removeFavoriteCalls, ["sign-1"])
        XCTAssertEqual(sut.favoriteSigns.map(\.id), ["sign-2"])
        XCTAssertNil(sut.offlineStatus(for: "sign-1"))
    }

    func testClearAllFavoritesClearsRepositoryAndState() async {
        favoritesRepository.entries = [FavoriteEntry(signId: "sign-1", offlineStatus: .readyOffline)]
        signRepository.loadAllSignsResult = .success([makeSign(id: "sign-1", word: "Привет")])
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-1", name: "Категория 1", order: 1)
        ])

        await sut.loadFavorites()

        sut.clearAllFavorites()

        XCTAssertEqual(favoritesRepository.clearAllFavoritesCallCount, 1)
        XCTAssertEqual(sut.favoriteSigns, [])
        XCTAssertNil(sut.offlineStatus(for: "sign-1"))
    }

    func testRepositoryUpdatesRefreshCategoryNamesForFavorites() async {
        favoritesRepository.entries = [FavoriteEntry(signId: "sign-1", offlineStatus: .readyOffline)]
        signRepository.dataUpdatedSubject.send(
            SyncData(
                categories: [makeCategory(id: "category-1", name: "Обновлённая", order: 1)],
                signs: [makeSign(id: "sign-1", word: "Привет")],
                lessons: [],
                lastUpdated: Date()
            )
        )

        let didUpdate = await waitUntil {
            self.sut.favoriteSigns.map(\.id) == ["sign-1"]
                && self.sut.categoryNamesById["category-1"] == "Обновлённая"
        }

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(sut.offlineStatus(for: "sign-1"), .readyOffline)
    }

    func testNetworkReconnectRetriesOnlyFailedFavoritesUsingSnapshots() async {
        let failedSign = makeSign(id: "sign-1", word: "Привет")
        favoritesRepository.entries = [
            FavoriteEntry(
                signId: "sign-1",
                snapshot: FavoriteSignSnapshot(sign: failedSign, categoryName: "Категория 1"),
                offlineStatus: .failed
            ),
            FavoriteEntry(
                signId: "sign-2",
                snapshot: FavoriteSignSnapshot(sign: makeSign(id: "sign-2", word: "Пока"), categoryName: "Категория 1"),
                offlineStatus: .readyOffline
            )
        ]

        networkMonitor.setConnectivityStatus(.disconnected)
        networkMonitor.setConnectivityStatus(.connected)

        // Сервис должен быть вызван только для failed жеста (sign-1), не для readyOffline (sign-2)
        let didRetry = await waitUntil {
            self.offlinePreparationService.prepareCalls.contains { $0.sign.id == "sign-1" }
        }

        XCTAssertTrue(didRetry)
        XCTAssertEqual(offlinePreparationService.prepareCalls.map(\.sign.id), ["sign-1"])
        XCTAssertEqual(offlinePreparationService.prepareCalls.first?.categoryName, "Категория 1")
        XCTAssertEqual(signRepository.getSignCallArguments, [])
    }

    func testLoadFavoritesRetriesPendingFavoritesWithRequiredVideos() async {
        let pendingSign = makeSign(id: "sign-1", word: "Привет")
        favoritesRepository.entries = [
            FavoriteEntry(
                signId: "sign-1",
                snapshot: FavoriteSignSnapshot(sign: pendingSign, categoryName: "Категория 1"),
                offlineStatus: .pending,
                requiredVideoIds: pendingSign.videosArray.map(\.id)
            )
        ]
        signRepository.loadAllSignsResult = .success([pendingSign])
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-1", name: "Категория 1", order: 1)
        ])

        await sut.loadFavorites()

        let didRetry = await waitUntil {
            self.offlinePreparationService.prepareCalls.contains { $0.sign.id == "sign-1" }
        }

        XCTAssertTrue(didRetry)
        XCTAssertEqual(offlinePreparationService.prepareCalls.map(\.sign.id), ["sign-1"])
    }

    func testReconnectFailureKeepsFavoriteAndMarksStatusFailed() async {
        let failedSign = makeSign(id: "sign-1", word: "Привет")
        favoritesRepository.entries = [
            FavoriteEntry(
                signId: "sign-1",
                snapshot: FavoriteSignSnapshot(sign: failedSign, categoryName: "Категория 1"),
                offlineStatus: .failed
            )
        ]
        offlinePreparationService.prepareResult = .failed

        networkMonitor.setConnectivityStatus(.disconnected)
        networkMonitor.setConnectivityStatus(.connected)

        let didFail = await waitUntil {
            self.sut.offlineStatus(for: "sign-1") == .failed
        }

        XCTAssertTrue(didFail)
        XCTAssertTrue(favoritesRepository.isFavorite(signId: "sign-1"))
        XCTAssertEqual(sut.offlineStatus(for: "sign-1"), .failed)
    }

    func testReconnectDoesNotRetryAlreadyReadyFavorites() async {
        favoritesRepository.entries = [
            FavoriteEntry(
                signId: "sign-1",
                snapshot: FavoriteSignSnapshot(sign: makeSign(id: "sign-1", word: "Привет"), categoryName: "Категория 1"),
                offlineStatus: .readyOffline
            )
        ]

        networkMonitor.setConnectivityStatus(.disconnected)
        networkMonitor.setConnectivityStatus(.connected)

        let didFinishRetryPass = await waitUntil {
            self.networkMonitor.checkConnectionCallCount == 1
                && self.favoritesRepository.reconcileOfflineStateCallCount == 1
        }

        XCTAssertTrue(didFinishRetryPass)
        // Для уже готовых жестов сервис не вызывается
        XCTAssertEqual(offlinePreparationService.prepareCalls.count, 0)
    }

    func testFavoritesAlwaysSortedAlphabeticallyAZ() async {
        favoritesRepository.entries = [
            FavoriteEntry(signId: "sign-b"),
            FavoriteEntry(signId: "sign-a")
        ]
        signRepository.loadAllSignsResult = .success([
            makeSign(id: "sign-b", word: "Б"),
            makeSign(id: "sign-a", word: "А")
        ])
        signRepository.loadCategoriesResult = .success([])

        await sut.loadFavorites()

        XCTAssertEqual(sut.favoriteSigns.map(\.word), ["А", "Б"])
    }

    private func makeSign(id: String, word: String) -> Sign {
        Sign(
            id: id,
            word: word,
            description: "Описание \(word)",
            categoryId: "category-1",
            videos: [TestFixtures.video],
            synonyms: nil
        )
    }

    private func makeCategory(id: String, name: String, order: Int) -> AppCategory {
        AppCategory(
            id: id,
            name: name,
            order: order,
            signCount: 1,
            icon: nil,
            color: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollInterval: UInt64 = 20_000_000,
        condition: @escaping @MainActor () -> Bool
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
