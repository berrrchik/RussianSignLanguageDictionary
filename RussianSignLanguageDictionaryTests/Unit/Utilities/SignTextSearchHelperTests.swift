import XCTest
@testable import RussianSignLanguageDictionary

final class SignTextSearchHelperTests: XCTestCase {
    func testFilterSignsMatchesWordCaseInsensitively() {
        let signs = [
            makeSign(id: "1", word: "Привет"),
            makeSign(id: "2", word: "Пока")
        ]

        let results = SignTextSearchHelper.filterSigns(signs, query: "прИВ")

        XCTAssertEqual(results.map(\.id), ["1"])
    }

    func testFilterSignsIncludesDescriptionOnlyWhenRequested() {
        let signs = [
            makeSign(id: "1", word: "Пока", description: "Жест приветствия"),
            makeSign(id: "2", word: "Привет")
        ]

        let withoutDescription = SignTextSearchHelper.filterSigns(
            signs,
            query: "привет",
            includeDescription: false
        )
        let withDescription = SignTextSearchHelper.filterSigns(
            signs,
            query: "привет",
            includeDescription: true
        )

        XCTAssertEqual(withoutDescription.map(\.id), ["2"])
        XCTAssertEqual(withDescription.map(\.id), ["1", "2"])
    }

    func testFilterSignsExcludingIdsSkipsExcludedMatches() {
        let signs = [
            makeSign(id: "1", word: "Привет"),
            makeSign(id: "2", word: "Приветствие"),
            makeSign(id: "3", word: "Пока")
        ]

        let results = SignTextSearchHelper.filterSigns(
            signs,
            query: "привет",
            excludingIds: ["1"]
        )

        XCTAssertEqual(results.map(\.id), ["2"])
    }

    func testSortByRelevancePrioritizesStartsWithOverContains() {
        let signs = [
            makeSign(id: "1", word: "Суперпривет"),
            makeSign(id: "2", word: "Приветствие")
        ]

        let results = SignTextSearchHelper.sortByRelevance(signs, query: "привет")

        XCTAssertEqual(results.map(\.id), ["2", "1"])
    }

    func testSortByRelevancePrioritizesEarlierMatchPosition() {
        let signs = [
            makeSign(id: "1", word: "Суперпривет"),
            makeSign(id: "2", word: "Мегапривет")
        ]

        let results = SignTextSearchHelper.sortByRelevance(signs, query: "привет")

        XCTAssertEqual(results.map(\.id), ["2", "1"])
    }

    func testSortByRelevanceUsesAlphabeticalTieBreak() {
        let signs = [
            makeSign(id: "1", word: "абпривет"),
            makeSign(id: "2", word: "авпривет")
        ]

        let results = SignTextSearchHelper.sortByRelevance(signs, query: "привет")

        XCTAssertEqual(results.map(\.word), ["абпривет", "авпривет"])
    }

    private func makeSign(
        id: String,
        word: String,
        description: String = "Описание"
    ) -> Sign {
        Sign(
            id: id,
            word: word,
            description: description,
            categoryId: "category-1",
            videos: [TestFixtures.video],
            synonyms: nil
        )
    }
}
