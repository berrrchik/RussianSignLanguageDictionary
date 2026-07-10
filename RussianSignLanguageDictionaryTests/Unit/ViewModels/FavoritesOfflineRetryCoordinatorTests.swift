import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class FavoritesOfflineRetryCoordinatorTests: XCTestCase {
    private var favoritesRepository: FavoritesRepositorySpy!
    private var signRepository: SignRepositorySpy!
    private var offlinePreparationService: OfflinePreparationServiceSpy!
    private var networkMonitor: NetworkMonitorSpy!
    private var sut: FavoritesOfflineRetryCoordinator!

    private var statusUpdates: [(signId: String, status: FavoriteOfflineStatus)] = []
    private var allResolvedCallCount = 0

    override func setUp() {
        super.setUp()
        favoritesRepository = FavoritesRepositorySpy()
        signRepository = SignRepositorySpy()
        offlinePreparationService = OfflinePreparationServiceSpy()
        networkMonitor = NetworkMonitorSpy()
        sut = FavoritesOfflineRetryCoordinator(
            favoritesRepository: favoritesRepository,
            signRepository: signRepository,
            offlinePreparationService: offlinePreparationService,
            networkMonitor: networkMonitor
        )
        statusUpdates = []
        allResolvedCallCount = 0
    }

    override func tearDown() {
        sut = nil
        favoritesRepository = nil
        signRepository = nil
        offlinePreparationService = nil
        networkMonitor = nil
        super.tearDown()
    }

    func testScheduleRetryIfNeededDoesNothingWhenNoRetryableEntries() async {
        favoritesRepository.entries = [FavoriteEntry(signId: "sign-1", offlineStatus: .readyOffline)]

        sut.scheduleRetryIfNeeded(categoryName: { $0 }, onStatusUpdate: recordStatusUpdate, onAllResolved: recordAllResolved)

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(offlinePreparationService.prepareCalls.count, 0)
        XCTAssertEqual(allResolvedCallCount, 0)
    }

    func testScheduleRetryIfNeededRetriesFailedEntryUsingSnapshot() async {
        let sign = makeSign(id: "sign-1", word: "Привет")
        favoritesRepository.entries = [
            FavoriteEntry(
                signId: "sign-1",
                snapshot: FavoriteSignSnapshot(sign: sign, categoryName: "Категория 1"),
                offlineStatus: .failed
            )
        ]
        offlinePreparationService.prepareResult = .readyOffline

        sut.scheduleRetryIfNeeded(categoryName: { $0 }, onStatusUpdate: recordStatusUpdate, onAllResolved: recordAllResolved)

        let didRetry = await waitUntil { self.offlinePreparationService.prepareCalls.count == 1 }
        XCTAssertTrue(didRetry)
        XCTAssertEqual(offlinePreparationService.prepareCalls.first?.sign.id, "sign-1")
        XCTAssertEqual(offlinePreparationService.prepareCalls.first?.categoryName, "Категория 1")
        XCTAssertEqual(signRepository.getSignCallArguments, [])

        let didUpdateStatus = await waitUntil {
            self.statusUpdates.contains { $0.signId == "sign-1" && $0.status == .readyOffline }
        }
        XCTAssertTrue(didUpdateStatus)
    }

    func testRetryFetchesLiveSignWhenNoSnapshotAvailable() async {
        favoritesRepository.entries = [FavoriteEntry(signId: "sign-1", offlineStatus: .failed)]
        let liveSign = makeSign(id: "sign-1", word: "Привет")
        signRepository.getSignResult = .success(liveSign)
        offlinePreparationService.prepareResult = .readyOffline

        sut.retryNow(categoryName: { _ in "Категория 1" }, onStatusUpdate: recordStatusUpdate, onAllResolved: recordAllResolved)

        let didFetchLiveSign = await waitUntil { self.signRepository.getSignCallArguments == ["sign-1"] }
        XCTAssertTrue(didFetchLiveSign)
        XCTAssertEqual(favoritesRepository.updateFavoriteSnapshotCalls.last?.sign.id, "sign-1")

        let didPrepare = await waitUntil { self.offlinePreparationService.prepareCalls.count == 1 }
        XCTAssertTrue(didPrepare)
    }

    func testRetryDoesNothingWhenOffline() async {
        favoritesRepository.entries = [FavoriteEntry(signId: "sign-1", offlineStatus: .failed)]
        networkMonitor.checkConnectionValue = false

        sut.retryNow(categoryName: { $0 }, onStatusUpdate: recordStatusUpdate, onAllResolved: recordAllResolved)

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(offlinePreparationService.prepareCalls.count, 0)
    }

    func testRetrySkipsEntryNoLongerFavorite() async {
        favoritesRepository.entries = [FavoriteEntry(signId: "sign-1", offlineStatus: .failed)]
        favoritesRepository.favoriteLookup["sign-1"] = false

        sut.retryNow(categoryName: { $0 }, onStatusUpdate: recordStatusUpdate, onAllResolved: recordAllResolved)

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(offlinePreparationService.prepareCalls.count, 0)
    }

    func testOnAllResolvedCalledWhenNoRetryableEntriesRemainAfterRetry() async {
        let sign = makeSign(id: "sign-1", word: "Привет")
        favoritesRepository.entries = [
            FavoriteEntry(
                signId: "sign-1",
                snapshot: FavoriteSignSnapshot(sign: sign, categoryName: "Категория 1"),
                offlineStatus: .failed
            )
        ]
        // Реальный OfflinePreparationService обновляет статус в репозитории — симулируем это,
        // чтобы retryableEntries() опустела и onAllResolved сработал.
        offlinePreparationService.prepareImplementation = { [weak self] preparedSign, _ in
            self?.favoritesRepository.updateOfflineStatus(
                signId: preparedSign.id,
                status: .readyOffline,
                downloadedVideoIds: [],
                requiredVideoIds: []
            )
            return .readyOffline
        }

        sut.scheduleRetryIfNeeded(categoryName: { $0 }, onStatusUpdate: recordStatusUpdate, onAllResolved: recordAllResolved)

        let didResolve = await waitUntil { self.allResolvedCallCount == 1 }
        XCTAssertTrue(didResolve)
    }

    func testCancelAllowsSubsequentRetryToRunCleanly() async {
        favoritesRepository.entries = [FavoriteEntry(signId: "sign-1", offlineStatus: .failed)]
        signRepository.getSignResult = .success(makeSign(id: "sign-1", word: "Привет"))

        sut.retryNow(categoryName: { $0 }, onStatusUpdate: recordStatusUpdate, onAllResolved: recordAllResolved)
        sut.cancel()

        sut.retryNow(categoryName: { $0 }, onStatusUpdate: recordStatusUpdate, onAllResolved: recordAllResolved)

        let didRetryAfterCancel = await waitUntil { self.offlinePreparationService.prepareCalls.count >= 1 }
        XCTAssertTrue(didRetryAfterCancel)
    }

    // MARK: - Helpers

    private func recordStatusUpdate(_ signId: String, _ status: FavoriteOfflineStatus) {
        statusUpdates.append((signId, status))
    }

    private func recordAllResolved() {
        allResolvedCallCount += 1
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
