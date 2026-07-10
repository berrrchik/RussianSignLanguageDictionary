import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class SearchCoordinatorTests: XCTestCase {
    private var networkMonitor: NetworkMonitorSpy!
    private var hybridSearchService: HybridSearchServiceSpy!
    private var hybridSearchServiceBuilder: HybridSearchServiceBuilderSpy!
    private var sut: SearchCoordinator!

    override func setUp() {
        super.setUp()
        networkMonitor = NetworkMonitorSpy()
        hybridSearchService = HybridSearchServiceSpy()
        hybridSearchServiceBuilder = HybridSearchServiceBuilderSpy(service: hybridSearchService)
        sut = SearchCoordinator(
            networkMonitor: networkMonitor,
            hybridSearchServiceBuilder: hybridSearchServiceBuilder
        )
    }

    override func tearDown() {
        sut = nil
        hybridSearchServiceBuilder = nil
        hybridSearchService = nil
        networkMonitor = nil
        super.tearDown()
    }

    func testUpdateSearchDataBuildsHybridService() {
        let signs = makeSigns()

        sut.updateSearchData(with: signs)

        XCTAssertEqual(hybridSearchServiceBuilder.makeCalls.count, 1)
        XCTAssertEqual(hybridSearchServiceBuilder.makeCalls.first?.signs.map(\.id), signs.map(\.id))
    }

    func testPerformSearchReturnsHybridResultsWhenHybridSucceeds() async {
        let signs = makeSigns()
        hybridSearchService.hybridSearchResult = .success([signs[0]])
        sut.updateSearchData(with: signs)

        let outcome = await sut.performSearch(query: "прив")

        XCTAssertEqual(outcome?.results.map(\.id), ["1"])
        XCTAssertEqual(outcome?.analyticsSearchType, "hybrid")
        XCTAssertEqual(hybridSearchService.hybridQueries, ["прив"])
        XCTAssertEqual(hybridSearchService.textQueries, [])
    }

    func testPerformSearchFallsBackToTextResultsWhenHybridFails() async {
        let signs = makeSigns()
        hybridSearchService.hybridSearchResult = .failure(SignRepositoryError.fileNotFound)
        hybridSearchService.textSearchResult = [signs[1]]
        sut.updateSearchData(with: signs)

        let outcome = await sut.performSearch(query: "прив")

        XCTAssertEqual(outcome?.results.map(\.id), ["2"])
        XCTAssertEqual(outcome?.analyticsSearchType, "text")
        XCTAssertEqual(hybridSearchService.hybridQueries, ["прив"])
        XCTAssertEqual(hybridSearchService.textQueries, ["прив"])
    }

    private func makeSigns() -> [Sign] {
        [
            makeSign(id: "1", word: "Привет", categoryId: "category-1"),
            makeSign(id: "2", word: "Приветствие", categoryId: "category-1"),
            makeSign(id: "3", word: "Алоха", categoryId: "category-2")
        ]
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
