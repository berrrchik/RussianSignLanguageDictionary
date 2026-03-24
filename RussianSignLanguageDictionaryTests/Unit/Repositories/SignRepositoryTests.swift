import XCTest
import Combine
@testable import RussianSignLanguageDictionary

final class SignRepositoryTests: XCTestCase {
    
    var sut: SignRepository!
    var syncRepository: SyncRepositorySpy!
    var networkMonitor: NetworkMonitorSpy!
    var cacheService: CacheService!
    var cacheDirectoryURL: URL!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        syncRepository = SyncRepositorySpy()
        networkMonitor = NetworkMonitorSpy()
        networkMonitor.isConnectedValue = true
        networkMonitor.checkConnectionValue = true
        cacheDirectoryURL = try? createTemporaryDirectory()
        cacheService = CacheService(cacheDirectoryURL: cacheDirectoryURL)
        try? cacheService.clearCache()
        cancellables = []
        sut = SignRepository(
            syncRepository: syncRepository,
            cacheService: cacheService,
            networkMonitor: networkMonitor
        )
    }
    
    override func tearDown() {
        try? cacheService?.clearCache()
        sut = nil
        syncRepository = nil
        networkMonitor = nil
        cacheService = nil
        cacheDirectoryURL = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testLoadAllSignsOnColdStartUsesServer() async throws {
        let signs = try await sut.loadAllSigns()
        
        XCTAssertEqual(signs.count, TestFixtures.syncData.signs.count)
        XCTAssertEqual(syncRepository.fetchAllDataCallCount, 1)
    }
    
    func testLoadAllSignsSavesDataToMemoryAndDiskCaches() async throws {
        _ = try await sut.loadAllSigns()

        XCTAssertEqual(sut.cachedSigns()?.count, TestFixtures.syncData.signs.count)
        XCTAssertEqual(try cacheService.load()?.signs.count, TestFixtures.syncData.signs.count)
    }

    func testLoadAllSignsUsesDiskCacheAndWarmsMemory() async throws {
        try cacheService.save(TestFixtures.syncData)
        networkMonitor.checkConnectionValue = false

        let signs = try await sut.loadAllSigns()

        XCTAssertEqual(signs.count, TestFixtures.syncData.signs.count)
        XCTAssertEqual(sut.cachedSigns()?.count, TestFixtures.syncData.signs.count)
        XCTAssertEqual(syncRepository.fetchAllDataCallCount, 0)
    }

    func testLoadAllSignsUsesMemoryCacheOnSubsequentCalls() async throws {
        try cacheService.save(TestFixtures.syncData)
        networkMonitor.checkConnectionValue = false
        _ = try await sut.loadAllSigns()
        
        let signs = try await sut.loadAllSigns()
        
        XCTAssertEqual(signs.count, TestFixtures.syncData.signs.count)
        XCTAssertEqual(syncRepository.fetchAllDataCallCount, 0)
    }

    func testLoadCategoriesReturnsSortedCategoriesByOrder() async throws {
        let unsortedData = SyncData(
            categories: [
                AppCategory(id: "b", name: "B", order: 2, signCount: 1, icon: nil, color: nil, createdAt: nil, updatedAt: nil),
                AppCategory(id: "a", name: "A", order: 1, signCount: 1, icon: nil, color: nil, createdAt: nil, updatedAt: nil)
            ],
            signs: TestFixtures.syncData.signs,
            lessons: TestFixtures.syncData.lessons,
            lastUpdated: TestFixtures.syncData.lastUpdated
        )
        syncRepository.fetchAllDataResult = .success(unsortedData)

        let categories = try await sut.loadCategories()
        
        XCTAssertEqual(categories.map(\.id), ["a", "b"])
    }
    
    func testGetSignByIdReturnsMatchingSign() async throws {
        let sign = try await sut.getSign(byId: TestFixtures.sign.id)
        
        XCTAssertEqual(sign?.id, TestFixtures.sign.id)
    }
    
    func testGetSignByIdNotFound() async throws {
        let sign = try await sut.getSign(byId: "missing-sign")
        
        XCTAssertNil(sign)
    }
    
    func testGetSignsByCategoryReturnsFilteredSigns() async throws {
        let signs = try await sut.getSigns(byCategory: TestFixtures.sign.categoryId)
        
        XCTAssertEqual(signs.map(\.id), [TestFixtures.sign.id])
    }
    
    func testSearchSignsEmptyQuery() async throws {
        let signs = try await sut.searchSigns(query: "")
        XCTAssertTrue(signs.isEmpty)
    }
    
    func testParallelLoadAllSignsUsesSingleFlight() async throws {
        let started = expectation(description: "fetch started")
        syncRepository.fetchAllDataImplementation = { _ in
            started.fulfill()
            try await Task.sleep(nanoseconds: 100_000_000)
            return TestFixtures.syncData
        }

        async let first = sut.loadAllSigns()
        async let second = sut.loadAllSigns()

        wait(for: [started], timeout: 1.0)
        let results = try await [first, second]

        XCTAssertEqual(results[0].count, TestFixtures.syncData.signs.count)
        XCTAssertEqual(results[1].count, TestFixtures.syncData.signs.count)
        XCTAssertEqual(syncRepository.fetchAllDataCallCount, 1)
    }

    func testBackgroundSyncIsScheduledOnlyOnce() async throws {
        try cacheService.save(TestFixtures.syncData)
        syncRepository.fetchAllDataImplementation = { provider in
            try await Task.sleep(nanoseconds: 100_000_000)
            return try provider()
        }

        _ = try await sut.loadAllSigns()
        _ = try await sut.loadAllSigns()
        XCTAssertTrue(waitForDebouncedUpdate(interval: 0.05, timeout: 1.0) {
            self.syncRepository.fetchAllDataCallCount == 1
        })
    }

    func testDataUpdatedPublisherDoesNotEmitWhenLastUpdatedIsUnchanged() async throws {
        try cacheService.save(TestFixtures.syncData)
        let firstExpectation = expectation(description: "no update for unchanged data")
        firstExpectation.isInverted = true

        sut.dataUpdatedPublisher
            .sink { _ in
                firstExpectation.fulfill()
            }
            .store(in: &cancellables)

        syncRepository.fetchAllDataImplementation = { provider in
            try provider()
        }

        _ = try await sut.loadAllSigns()
        wait(for: [firstExpectation], timeout: 0.2)
    }

    func testDataUpdatedPublisherEmitsWhenLastUpdatedChanges() async throws {
        let initialData = TestFixtures.syncData
        let updatedData = SyncData(
            categories: initialData.categories,
            signs: initialData.signs,
            lessons: initialData.lessons,
            lastUpdated: initialData.lastUpdated.addingTimeInterval(60)
        )
        try cacheService.save(initialData)

        let updateExpectation = expectation(description: "publisher emits for new lastUpdated")
        sut.dataUpdatedPublisher
            .sink { data in
                XCTAssertEqual(data.lastUpdated, updatedData.lastUpdated)
                updateExpectation.fulfill()
            }
            .store(in: &cancellables)

        syncRepository.fetchAllDataImplementation = { _ in
            updatedData
        }

        _ = try await sut.loadAllSigns()
        wait(for: [updateExpectation], timeout: 1.0)
    }
}
