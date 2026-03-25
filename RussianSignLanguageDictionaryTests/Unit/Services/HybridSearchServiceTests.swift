import XCTest
@testable import RussianSignLanguageDictionary

final class HybridSearchServiceTests: XCTestCase {
    private var sbertService: SBERTSearchServiceSpy!
    private var networkMonitor: NetworkMonitorSpy!

    override func setUp() {
        super.setUp()
        sbertService = SBERTSearchServiceSpy()
        networkMonitor = NetworkMonitorSpy()
        networkMonitor.checkConnectionValue = true
    }

    override func tearDown() {
        sbertService = nil
        networkMonitor = nil
        super.tearDown()
    }

    func testPerformHybridSearchReturnsWhitespaceQueryAsAllSigns() async throws {
        let signs = makeSearchSigns()
        let sut = makeSUT(signs: signs)

        let results = try await sut.performHybridSearch(query: "   ", limit: 20)

        XCTAssertEqual(results.map(\.id), signs.map(\.id))
        XCTAssertTrue(sbertService.queries.isEmpty)
    }

    func testPerformHybridSearchPrioritizesExactMatchesThenSupplementsWithSBERTAndText() async throws {
        let signs = makeSearchSigns()
        sbertService.searchResult = .success([
            SBERTSearchResult(id: "sbert", word: "Помощь", similarity: 0.92),
            SBERTSearchResult(id: "exact", word: "Привет", similarity: 0.91)
        ])
        let sut = makeSUT(signs: signs)

        let results = try await sut.performHybridSearch(query: "привет", limit: 3)

        XCTAssertEqual(results.map(\.id), ["exact", "sbert", "text"])
    }

    func testPerformHybridSearchRespectsLimit() async throws {
        let signs = makeSearchSigns()
        sbertService.searchResult = .success([
            SBERTSearchResult(id: "sbert", word: "Помощь", similarity: 0.92)
        ])
        let sut = makeSUT(signs: signs)

        let results = try await sut.performHybridSearch(query: "привет", limit: 2)

        XCTAssertEqual(results.map(\.id), ["exact", "sbert"])
    }

    func testPerformHybridSearchSkipsSBERTWhenOffline() async throws {
        let signs = makeSearchSigns()
        networkMonitor.checkConnectionValue = false
        let sut = makeSUT(signs: signs)

        let results = try await sut.performHybridSearch(query: "привет", limit: 3)

        XCTAssertEqual(results.map(\.id), ["exact", "text", "late"])
        XCTAssertTrue(sbertService.queries.isEmpty)
    }

    func testPerformHybridSearchFallsBackToTextWhenSBERTFails() async throws {
        let signs = makeSearchSigns()
        sbertService.searchResult = .failure(SBERTSearchError.invalidResponse)
        let sut = makeSUT(signs: signs)

        let results = try await sut.performHybridSearch(query: "привет", limit: 3)

        XCTAssertEqual(results.map(\.id), ["exact", "text", "late"])
    }

    func testPerformTextSearchReturnsAllSignsForWhitespaceQuery() {
        let signs = makeSearchSigns()
        let sut = makeSUT(signs: signs)

        let results = sut.performTextSearch(query: "   ", limit: 20)

        XCTAssertEqual(results.map(\.id), signs.map(\.id))
    }

    private func makeSUT(signs: [Sign]) -> HybridSearchService {
        HybridSearchService(
            signs: signs,
            networkMonitor: networkMonitor,
            sbertService: sbertService
        )
    }

    private func makeSearchSigns() -> [Sign] {
        [
            makeSign(id: "exact", word: "Привет"),
            makeSign(id: "text", word: "Приветствие"),
            makeSign(id: "late", word: "Суперпривет"),
            makeSign(id: "sbert", word: "Помощь")
        ]
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
}
