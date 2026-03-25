import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class SyncViewModelTests: XCTestCase {
    private var sut: SyncViewModel!
    private var syncRepository: SyncRepositorySpy!
    private var networkMonitor: NetworkMonitorSpy!
    private var cacheService: CacheService!
    private var cacheDirectoryURL: URL!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        syncRepository = SyncRepositorySpy()
        networkMonitor = NetworkMonitorSpy()
        cacheDirectoryURL = try? createTemporaryDirectory()
        cacheService = CacheService(cacheDirectoryURL: cacheDirectoryURL)
        userDefaults = makeIsolatedUserDefaults()
        sut = makeSut()
    }

    override func tearDown() {
        sut = nil
        syncRepository = nil
        networkMonitor = nil
        cacheService = nil
        cacheDirectoryURL = nil
        userDefaults = nil
        super.tearDown()
    }

    func testInitLoadsLastSyncDateFromUserDefaults() {
        let storedDate = Date(timeIntervalSince1970: 1_700_000_000)
        userDefaults.set(storedDate, forKey: "lastSyncDate")

        let sut = makeSut()

        XCTAssertEqual(sut.lastSyncDate, storedDate)
    }

    func testSyncReturnsSilentlyWhenOffline() async {
        networkMonitor.checkConnectionValue = false

        await sut.sync()

        XCTAssertFalse(sut.isSyncing)
        XCTAssertNil(sut.syncError)
        XCTAssertEqual(syncRepository.checkForUpdatesArguments.count, 0)
        XCTAssertEqual(syncRepository.fetchAllDataCallCount, 0)
    }

    func testSyncChecksForUpdatesWithNilDateByDefault() async {
        syncRepository.checkForUpdatesResult = .success(SyncMetadata(
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_050),
            hasUpdates: false
        ))

        await sut.sync()

        XCTAssertEqual(syncRepository.checkForUpdatesArguments.count, 1)
        XCTAssertNil(syncRepository.checkForUpdatesArguments[0])
        XCTAssertFalse(sut.isSyncing)
    }

    func testSyncWithoutUpdatesDoesNotFetchOrShowError() async {
        syncRepository.checkForUpdatesResult = .success(SyncMetadata(
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_010),
            hasUpdates: false
        ))

        await sut.sync()

        XCTAssertEqual(syncRepository.fetchAllDataCallCount, 0)
        XCTAssertNil(sut.syncError)
        XCTAssertNil(sut.lastSyncDate)
        XCTAssertFalse(sut.isSyncing)
    }

    func testSyncWithUpdatesFetchesSavesAndPersistsLastSyncDate() async throws {
        let updatedDate = Date(timeIntervalSince1970: 1_700_000_100)
        let syncData = SyncData(
            categories: [TestFixtures.category],
            signs: [TestFixtures.sign],
            lessons: [TestFixtures.lesson],
            lastUpdated: updatedDate
        )
        syncRepository.checkForUpdatesResult = .success(SyncMetadata(lastUpdated: updatedDate, hasUpdates: true))
        syncRepository.fetchAllDataResult = .success(syncData)

        await sut.sync()

        XCTAssertEqual(syncRepository.fetchAllDataCallCount, 1)
        XCTAssertEqual(sut.lastSyncDate, updatedDate)
        XCTAssertEqual(userDefaults.object(forKey: "lastSyncDate") as? Date, updatedDate)
        XCTAssertEqual(try cacheService.load()?.lastUpdated, updatedDate)
        XCTAssertFalse(sut.isSyncing)
    }

    func testSyncSuppressesExpectedNoInternetError() async {
        syncRepository.checkForUpdatesResult = .failure(SyncError.noInternet)

        await sut.sync()

        XCTAssertNil(sut.syncError)
        XCTAssertFalse(sut.isSyncing)
    }

    func testSyncSuppressesExpectedServerUnavailableError() async {
        syncRepository.checkForUpdatesResult = .failure(SyncError.serverUnavailable)

        await sut.sync()

        XCTAssertNil(sut.syncError)
        XCTAssertFalse(sut.isSyncing)
    }

    func testSyncSuppressesExpectedNetworkError() async {
        syncRepository.checkForUpdatesResult = .failure(SyncError.networkError(URLError(.timedOut)))

        await sut.sync()

        XCTAssertNil(sut.syncError)
        XCTAssertFalse(sut.isSyncing)
    }

    func testSyncShowsMappedErrorForUnexpectedSyncError() async {
        syncRepository.checkForUpdatesResult = .failure(SyncError.invalidResponse)

        await sut.sync()

        XCTAssertEqual(sut.syncError, "Неверный ответ сервера. Попробуйте позже.")
        XCTAssertFalse(sut.isSyncing)
    }

    func testSyncShowsGenericMessageForUnexpectedNonSyncError() async {
        syncRepository.checkForUpdatesResult = .failure(NSError(domain: "test", code: 42, userInfo: [
            NSLocalizedDescriptionKey: "Boom"
        ]))

        await sut.sync()

        XCTAssertEqual(sut.syncError, "Ошибка синхронизации: Boom")
        XCTAssertFalse(sut.isSyncing)
    }

    func testSyncPreventsDuplicateRequestsWhileAlreadyRunning() async {
        var continuation: CheckedContinuation<SyncMetadata, Never>?
        syncRepository.checkForUpdatesImplementation = { _ in
            return await withCheckedContinuation { checkedContinuation in
                continuation = checkedContinuation
            }
        }

        let first = Task { await self.sut.sync() }
        let didStartSync = await waitUntil {
            self.sut.isSyncing
        }
        XCTAssertTrue(didStartSync)

        let second = Task { await self.sut.sync() }
        continuation?.resume(returning: SyncMetadata(lastUpdated: Date(), hasUpdates: false))

        await first.value
        await second.value

        XCTAssertEqual(syncRepository.checkForUpdatesArguments.count, 1)
    }

    func testClearErrorResetsSyncError() {
        sut.syncError = "Ошибка"

        sut.clearError()

        XCTAssertNil(sut.syncError)
    }

    private func makeSut() -> SyncViewModel {
        SyncViewModel(
            syncRepository: syncRepository,
            cacheService: cacheService,
            networkMonitor: networkMonitor,
            userDefaults: userDefaults
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
