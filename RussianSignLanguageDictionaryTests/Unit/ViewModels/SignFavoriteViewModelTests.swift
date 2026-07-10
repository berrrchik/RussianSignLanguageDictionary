import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class SignFavoriteViewModelTests: XCTestCase {
    private var favoritesRepository: FavoritesRepositorySpy!
    private var offlinePreparationService: OfflinePreparationServiceSpy!

    override func setUp() {
        super.setUp()
        favoritesRepository = FavoritesRepositorySpy()
        offlinePreparationService = OfflinePreparationServiceSpy()
    }

    override func tearDown() {
        favoritesRepository = nil
        offlinePreparationService = nil
        super.tearDown()
    }

    func testInitReflectsCurrentFavoriteStateFromRepository() {
        favoritesRepository.favoriteLookup["sign-1"] = true
        favoritesRepository.entries = [FavoriteEntry(signId: "sign-1", offlineStatus: .readyOffline)]

        let sut = makeSut()

        XCTAssertTrue(sut.isFavorite)
        XCTAssertEqual(sut.offlineStatus, .readyOffline)
    }

    func testToggleAddsFavoriteWithSnapshotAndMarksPendingImmediately() {
        favoritesRepository.favoriteLookup["sign-1"] = false
        let sut = makeSut()

        sut.toggle(categoryName: "Категория 1")

        XCTAssertTrue(sut.isFavorite)
        XCTAssertEqual(favoritesRepository.addFavoriteWithSnapshotCalls.map(\.sign.id), ["sign-1"])
        XCTAssertEqual(favoritesRepository.updateOfflineStatusCalls.first?.status, .pending)
        XCTAssertEqual(sut.offlineStatus, .pending)
        XCTAssertEqual(favoritesRepository.removeFavoriteCalls, [])
    }

    func testToggleRemovesFavoriteWhenCurrentlyFavorite() {
        favoritesRepository.favoriteLookup["sign-1"] = true
        favoritesRepository.entries = [FavoriteEntry(signId: "sign-1", offlineStatus: .readyOffline)]
        let sut = makeSut()

        sut.toggle(categoryName: "Категория 1")

        XCTAssertFalse(sut.isFavorite)
        XCTAssertNil(sut.offlineStatus)
        XCTAssertEqual(favoritesRepository.removeFavoriteCalls, ["sign-1"])
        XCTAssertEqual(favoritesRepository.addFavoriteCalls, [])
    }

    func testTogglePreservesFavoriteWhenOfflinePreparationFails() async {
        favoritesRepository.favoriteLookup["sign-1"] = false
        offlinePreparationService.prepareResult = .failed
        let sut = makeSut()

        sut.toggle(categoryName: "Категория 1")

        let didFail = await waitUntil {
            sut.offlineStatus == .failed
        }

        XCTAssertTrue(didFail)
        XCTAssertTrue(sut.isFavorite)
        XCTAssertEqual(favoritesRepository.removeFavoriteCalls, [])
    }

    func testToggleMarksReadyOfflineAfterSuccessfulPreparation() async {
        favoritesRepository.favoriteLookup["sign-1"] = false
        offlinePreparationService.prepareResult = .readyOffline
        let sut = makeSut()

        sut.toggle(categoryName: "Категория 1")

        let didComplete = await waitUntil {
            sut.offlineStatus == .readyOffline
        }

        XCTAssertTrue(didComplete)
        XCTAssertEqual(offlinePreparationService.prepareCalls.count, 1)
        XCTAssertEqual(offlinePreparationService.prepareCalls.first?.sign.id, "sign-1")
    }

    func testCheckStatusReconcilesAndRefreshesFromRepository() async {
        favoritesRepository.favoriteLookup["sign-1"] = false
        let sut = makeSut()

        favoritesRepository.favoriteLookup["sign-1"] = true
        favoritesRepository.entries = [FavoriteEntry(signId: "sign-1", offlineStatus: .readyOffline)]

        sut.checkStatus()

        let didRefresh = await waitUntil {
            sut.isFavorite && sut.offlineStatus == .readyOffline
        }
        XCTAssertTrue(didRefresh)
        XCTAssertEqual(favoritesRepository.reconcileOfflineStateCallCount, 1)
    }

    func testUpdateSnapshotIfFavoriteUpdatesRepositoryOnlyWhenFavorite() {
        favoritesRepository.favoriteLookup["sign-1"] = false
        let sut = makeSut()

        sut.updateSnapshotIfFavorite(categoryName: "Категория 1")
        XCTAssertEqual(favoritesRepository.updateFavoriteSnapshotCalls.count, 0)

        favoritesRepository.favoriteLookup["sign-1"] = true
        favoritesRepository.entries = [FavoriteEntry(signId: "sign-1")]
        let favoriteSut = makeSut()

        favoriteSut.updateSnapshotIfFavorite(categoryName: "Категория 1")
        XCTAssertEqual(favoritesRepository.updateFavoriteSnapshotCalls.last?.sign.id, "sign-1")
        XCTAssertEqual(favoritesRepository.updateFavoriteSnapshotCalls.last?.categoryName, "Категория 1")
    }

    // MARK: - Helpers

    private func makeSut() -> SignFavoriteViewModel {
        SignFavoriteViewModel(
            sign: TestFixtures.sign,
            favoritesRepository: favoritesRepository,
            offlinePreparationService: offlinePreparationService
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
