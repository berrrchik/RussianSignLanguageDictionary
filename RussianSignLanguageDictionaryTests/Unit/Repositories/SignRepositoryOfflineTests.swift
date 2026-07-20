import XCTest
@testable import RussianSignLanguageDictionary

/// Тесты для проверки работы SignRepository с интернетом и без (офлайн-режим)
@MainActor
final class SignRepositoryOfflineTests: XCTestCase {
    
    var sut: SignRepository!
    var networkMonitor: NetworkMonitorSpy!
    var syncRepository: SyncRepositorySpy!
    var cacheService: CacheService!
    var cacheDirectoryURL: URL!
    
    override func setUp() {
        super.setUp()
        networkMonitor = NetworkMonitorSpy()
        syncRepository = SyncRepositorySpy()
        cacheDirectoryURL = try? createTemporaryDirectory()
        cacheService = CacheService(cacheDirectoryURL: cacheDirectoryURL)
        
        sut = SignRepository(
            syncRepository: syncRepository,
            cacheService: cacheService,
            networkMonitor: networkMonitor
        )
    }
    
    override func tearDown() {
        try? cacheService?.clearCache()
        sut = nil
        networkMonitor = nil
        syncRepository = nil
        cacheService = nil
        cacheDirectoryURL = nil
        super.tearDown()
    }
    
    func testFirstLaunchOfflineWithoutCacheThrowsNoDataAvailable() async {
        networkMonitor.checkConnectionValue = false

        do {
            _ = try await sut.loadAllSigns()
            XCTFail("Expected noDataAvailable")
        } catch let error as SignRepositoryError {
            XCTAssertEqual(error, .noDataAvailable)
            XCTAssertEqual(sut.currentDataStatus, .noData(.noInternet))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFirstLaunchWithServerUnavailableWithoutCachePublishesBlockingServerStatus() async {
        networkMonitor.setConnectivityStatus(.connected)
        syncRepository.fetchAllDataResult = .failure(SyncError.serverUnavailable)

        do {
            _ = try await sut.loadAllSigns()
            XCTFail("Expected noDataAvailable")
        } catch let error as SignRepositoryError {
            XCTAssertEqual(error, .noDataAvailable)
            XCTAssertEqual(sut.currentDataStatus, .noData(.serverUnavailable))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testOfflineWithDiskCacheLoadsSuccessfully() async throws {
        try cacheService.save(TestFixtures.syncData)
        networkMonitor.checkConnectionValue = false

        let signs = try await sut.loadAllSigns()

        XCTAssertEqual(signs.count, TestFixtures.syncData.signs.count)
    }
    
    func testOfflineCategoriesUseDiskCache() async throws {
        try cacheService.save(TestFixtures.syncData)
        networkMonitor.checkConnectionValue = false

        let categories = try await sut.loadCategories()

        XCTAssertEqual(categories.count, TestFixtures.syncData.categories.count)
    }

    func testOfflineSearchUsesCachedData() async throws {
        try cacheService.save(TestFixtures.syncData)
        networkMonitor.checkConnectionValue = false

        let results = try await sut.searchSigns(query: "прив")

        XCTAssertEqual(results.map(\.id), [TestFixtures.sign.id])
    }
}
