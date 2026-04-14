import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class SearchViewModelTests: XCTestCase {
    var sut: SearchViewModel!
    var signRepository: SignRepositorySpy!
    var networkMonitor: NetworkMonitorSpy!
    var categoryService: CategoryServiceSpy!
    var hybridSearchService: HybridSearchServiceSpy!
    var hybridSearchServiceBuilder: HybridSearchServiceBuilderSpy!
    
    override func setUp() {
        super.setUp()
        signRepository = SignRepositorySpy()
        signRepository.loadAllSignsResult = .success([])
        signRepository.cachedSignsValue = nil
        networkMonitor = NetworkMonitorSpy()
        networkMonitor.checkConnectionValue = true
        categoryService = CategoryServiceSpy()
        hybridSearchService = HybridSearchServiceSpy()
        hybridSearchServiceBuilder = HybridSearchServiceBuilderSpy(service: hybridSearchService)
        sut = SearchViewModel(
            signRepository: signRepository,
            networkMonitor: networkMonitor,
            categoryService: categoryService,
            hybridSearchServiceBuilder: hybridSearchServiceBuilder
        )
    }
    
    override func tearDown() {
        sut = nil
        signRepository = nil
        networkMonitor = nil
        categoryService = nil
        hybridSearchService = nil
        hybridSearchServiceBuilder = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertEqual(sut.searchQuery, "")
        XCTAssertEqual(sut.searchResults, [])
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isReady)
    }
    
    func testLoadAllSignsLoadsInitialResults() async {
        let signs = makeSigns()
        signRepository.loadAllSignsResult = .success(signs)

        await sut.loadAllSigns()

        XCTAssertEqual(sut.searchResults.map(\.id), signs.map(\.id))
        XCTAssertTrue(sut.isReady)
        XCTAssertNil(sut.errorMessage)
    }

    func testDebouncePerformsSearchAfterQueryUpdate() async {
        let signs = makeSigns()
        signRepository.cachedSignsValue = signs
        hybridSearchService.hybridSearchResult = .success([signs[0]])

        let sut = SearchViewModel(
            signRepository: signRepository,
            networkMonitor: networkMonitor,
            categoryService: categoryService,
            hybridSearchServiceBuilder: hybridSearchServiceBuilder
        )
        self.sut = sut

        sut.searchQuery = "прив"

        let didPerformDebouncedSearch = await waitUntil {
            sut.searchResults.map(\.id) == [signs[0].id]
        }
        XCTAssertTrue(didPerformDebouncedSearch)
        XCTAssertTrue(hybridSearchService.hybridQueries.contains("прив"))
    }

    func testEmptyQueryShowsFullList() async {
        let signs = makeSigns()
        signRepository.loadAllSignsResult = .success(signs)
        await sut.loadAllSigns()

        await sut.performSearch(query: "")

        XCTAssertEqual(sut.searchResults.map(\.id), signs.map(\.id))
    }

    func testGroupedResultsUsesSingleSectionForActiveSearch() async {
        let signs = makeSigns()
        signRepository.loadAllSignsResult = .success(signs)
        hybridSearchService.hybridSearchResult = .success([signs[0], signs[1]])
        await sut.loadAllSigns()
        sut.searchQuery = "прив"

        let didLoadSearchResults = await waitUntil {
            self.sut.searchResults.count == 2
        }
        XCTAssertTrue(didLoadSearchResults)
        XCTAssertEqual(sut.groupedResults.count, 1)
        XCTAssertEqual(sut.groupedResults.first?.id, "search_results")
    }

    func testGroupedResultsAppliesCategoryFilter() async {
        let signs = makeSigns()
        signRepository.loadAllSignsResult = .success(signs)

        await sut.loadAllSigns()
        sut.selectedCategoryId = "category-2"

        XCTAssertEqual(sut.groupedResults.flatMap(\.signs).map(\.id), ["3"])
    }

    func testGroupedResultsRespectsDescendingSortOrder() async {
        let signs = makeSigns()
        signRepository.loadAllSignsResult = .success(signs)

        await sut.loadAllSigns()
        sut.sortOrder = .descending

        XCTAssertEqual(sut.groupedResults.map(\.letter), ["П", "А"])
    }

    func testClearSearchResetsQueryAndResults() async {
        let signs = makeSigns()
        signRepository.loadAllSignsResult = .success(signs)
        hybridSearchService.hybridSearchResult = .success([signs[0]])

        await sut.loadAllSigns()
        await sut.performSearch(query: "прив")

        let didApplySearchResults = await waitUntil {
            self.sut.searchResults.map(\.id) == [signs[0].id]
        }
        XCTAssertTrue(didApplySearchResults)

        sut.clearSearch()

        XCTAssertEqual(sut.searchQuery, "")
        XCTAssertEqual(sut.searchResults.map(\.id), signs.map(\.id))
        XCTAssertNil(sut.errorMessage)
    }

    func testPreloadFromCacheInitializesResultsAndReadyState() {
        let signs = makeSigns()
        signRepository.cachedSignsValue = signs

        let sut = SearchViewModel(
            signRepository: signRepository,
            networkMonitor: networkMonitor,
            categoryService: categoryService,
            hybridSearchServiceBuilder: hybridSearchServiceBuilder
        )

        XCTAssertEqual(sut.searchResults.map(\.id), signs.map(\.id))
        XCTAssertTrue(sut.isReady)
    }

    func testLoadAllSignsMapsErrorMessage() async {
        signRepository.loadAllSignsResult = .failure(SignRepositoryError.fileNotFound)

        await sut.loadAllSigns()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testLoadAllSignsEnablesOfflineModeWhenNetworkUnavailable() async {
        let signs = makeSigns()
        signRepository.loadAllSignsResult = .success(signs)
        networkMonitor.checkConnectionValue = false

        await sut.loadAllSigns()

        XCTAssertTrue(sut.isOfflineMode)
        XCTAssertNotNil(sut.offlineMessage)
    }

    func testPerformSearchCancelsPreviousTaskOnQueryChange() async {
        let signs = makeSigns()
        signRepository.cachedSignsValue = signs

        let sut = SearchViewModel(
            signRepository: signRepository,
            networkMonitor: networkMonitor,
            categoryService: categoryService,
            hybridSearchServiceBuilder: hybridSearchServiceBuilder
        )
        self.sut = sut

        let firstSearchStarted = expectation(description: "First search started")
        let secondSearchStarted = expectation(description: "Second search started")
        var releaseFirstSearch: CheckedContinuation<[Sign], Never>?
        hybridSearchService.hybridSearchImplementation = { query, _, _ in
            if query == "прив" {
                firstSearchStarted.fulfill()
                return await withCheckedContinuation { continuation in
                    releaseFirstSearch = continuation
                }
            }

            secondSearchStarted.fulfill()
            return [signs[2]]
        }

        sut.searchQuery = "прив"
        await fulfillment(of: [firstSearchStarted], timeout: 2.0)
        sut.searchQuery = "ал"

        await fulfillment(of: [secondSearchStarted], timeout: 2.0)
        releaseFirstSearch?.resume(returning: [signs[0]])
        let didApplyLatestResults = await waitUntil {
            sut.searchResults.map(\.id) == [signs[2].id]
        }
        XCTAssertTrue(didApplyLatestResults)
        XCTAssertEqual(sut.searchResults.map(\.id), [signs[2].id])
    }

    private func makeSigns() -> [Sign] {
        [
            makeSign(id: "1", word: "Привет", categoryId: "category-1"),
            makeSign(id: "2", word: "Приветствие", categoryId: "category-1"),
            makeSign(id: "3", word: "Алоха", categoryId: "category-2")
        ]
    }

    private func waitUntil(
        timeout: TimeInterval = 1.5,
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

    private func makeSign(id: String, word: String, categoryId: String) -> Sign {
        Sign(
            id: id,
            word: word,
            description: "Описание для \(word)",
            categoryId: categoryId,
            videos: [TestFixtures.video],
            synonyms: nil
        )
    }
}
