import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class SearchViewModelTests: XCTestCase {
    var sut: SearchViewModel!
    var signRepository: SignRepositorySpy!
    var networkMonitor: NetworkMonitorSpy!
    var hybridSearchService: HybridSearchServiceSpy!
    var hybridSearchServiceBuilder: HybridSearchServiceBuilderSpy!
    
    override func setUp() {
        super.setUp()
        signRepository = SignRepositorySpy()
        signRepository.loadAllSignsResult = .success([])
        signRepository.cachedSignsValue = nil
        signRepository.cachedDataValue = nil
        networkMonitor = NetworkMonitorSpy()
        networkMonitor.checkConnectionValue = true
        hybridSearchService = HybridSearchServiceSpy()
        hybridSearchServiceBuilder = HybridSearchServiceBuilderSpy(service: hybridSearchService)
        sut = SearchViewModel(
            signRepository: signRepository,
            networkMonitor: networkMonitor,
            hybridSearchServiceBuilder: hybridSearchServiceBuilder
        )
    }
    
    override func tearDown() {
        sut = nil
        signRepository = nil
        networkMonitor = nil
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
        signRepository.loadCategoriesResult = .success(makeCategories())

        await sut.loadAllSigns()

        XCTAssertEqual(sut.searchResults.map(\.id), signs.map(\.id))
        XCTAssertEqual(sut.categoryNamesById["category-1"], "Категория 1")
        XCTAssertTrue(sut.isReady)
        XCTAssertNil(sut.errorMessage)
    }

    func testDebouncePerformsSearchAfterQueryUpdate() async {
        let signs = makeSigns()
        signRepository.cachedSignsValue = signs
        signRepository.loadCategoriesResult = .success(makeCategories())
        hybridSearchService.hybridSearchResult = .success([signs[0]])

        let sut = SearchViewModel(
            signRepository: signRepository,
            networkMonitor: networkMonitor,
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
        signRepository.loadCategoriesResult = .success(makeCategories())
        await sut.loadAllSigns()

        await sut.performSearch(query: "")

        XCTAssertEqual(sut.searchResults.map(\.id), signs.map(\.id))
    }

    func testGroupedResultsUsesSingleSectionForActiveSearch() async {
        let signs = makeSigns()
        signRepository.loadAllSignsResult = .success(signs)
        signRepository.loadCategoriesResult = .success(makeCategories())
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
        signRepository.loadCategoriesResult = .success(makeCategories())

        await sut.loadAllSigns()
        sut.selectedCategoryId = "category-2"

        XCTAssertEqual(sut.groupedResults.flatMap(\.signs).map(\.id), ["3"])
    }

    func testGroupedResultsRespectsDescendingSortOrder() async {
        let signs = makeSigns()
        signRepository.loadAllSignsResult = .success(signs)
        signRepository.loadCategoriesResult = .success(makeCategories())

        await sut.loadAllSigns()
        sut.sortOrder = .descending

        XCTAssertEqual(sut.groupedResults.map(\.letter), ["П", "А"])
    }

    func testClearSearchResetsQueryAndResults() async {
        let signs = makeSigns()
        signRepository.loadAllSignsResult = .success(signs)
        signRepository.loadCategoriesResult = .success(makeCategories())
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

    func testPreloadFromCachedDataInitializesResultsCategoryNamesAndSkipsReload() async {
        let signs = makeSigns()
        let categories = makeCategories()
        signRepository.cachedDataValue = SyncData(
            categories: categories,
            signs: signs,
            lessons: [],
            lastUpdated: Date()
        )

        let sut = SearchViewModel(
            signRepository: signRepository,
            networkMonitor: networkMonitor,
            hybridSearchServiceBuilder: hybridSearchServiceBuilder
        )

        XCTAssertEqual(sut.searchResults.map(\.id), signs.map(\.id))
        XCTAssertEqual(sut.categoryNamesById["category-1"], "Категория 1")
        XCTAssertTrue(sut.isReady)

        await sut.loadAllSigns()

        XCTAssertEqual(signRepository.loadAllSignsCallCount, 0)
        XCTAssertEqual(signRepository.loadCategoriesCallCount, 0)
    }

    func testLoadAllSignsMapsErrorMessage() async {
        signRepository.loadAllSignsResult = .failure(SignRepositoryError.fileNotFound)

        await sut.loadAllSigns()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testPerformSearchCancelsPreviousTaskOnQueryChange() async {
        let signs = makeSigns()
        signRepository.cachedSignsValue = signs
        signRepository.loadCategoriesResult = .success(makeCategories())

        let sut = SearchViewModel(
            signRepository: signRepository,
            networkMonitor: networkMonitor,
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

    func testRepositoryUpdatesRefreshPreparedCategoryNames() async {
        signRepository.dataUpdatedSubject.send(
            SyncData(
                categories: [
                    AppCategory(
                        id: "category-1",
                        name: "Обновлённая категория",
                        order: 1,
                        signCount: 1,
                        icon: nil,
                        color: nil,
                        createdAt: nil,
                        updatedAt: nil
                    )
                ],
                signs: [makeSign(id: "1", word: "Привет", categoryId: "category-1")],
                lessons: [],
                lastUpdated: Date()
            )
        )

        let didUpdate = await waitUntil {
            self.sut.searchResults.map(\.id) == ["1"]
                && self.sut.categoryNamesById["category-1"] == "Обновлённая категория"
        }

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(sut.searchResults.map(\.id), ["1"])
        XCTAssertEqual(sut.categoryNamesById["category-1"], "Обновлённая категория")
    }

    private func makeSigns() -> [Sign] {
        [
            makeSign(id: "1", word: "Привет", categoryId: "category-1"),
            makeSign(id: "2", word: "Приветствие", categoryId: "category-1"),
            makeSign(id: "3", word: "Алоха", categoryId: "category-2")
        ]
    }

    private func makeCategories() -> [AppCategory] {
        [
            AppCategory(
                id: "category-1",
                name: "Категория 1",
                order: 1,
                signCount: 2,
                icon: nil,
                color: nil,
                createdAt: nil,
                updatedAt: nil
            ),
            AppCategory(
                id: "category-2",
                name: "Категория 2",
                order: 2,
                signCount: 1,
                icon: nil,
                color: nil,
                createdAt: nil,
                updatedAt: nil
            )
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
