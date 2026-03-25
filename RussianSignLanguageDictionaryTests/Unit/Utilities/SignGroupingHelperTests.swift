import XCTest
@testable import RussianSignLanguageDictionary

final class SignGroupingHelperTests: XCTestCase {
    func testGroupByFirstLetterCreatesLetterSections() {
        let signs = [
            makeSign(id: "1", word: "Арбуз"),
            makeSign(id: "2", word: "Аист"),
            makeSign(id: "3", word: "Борщ")
        ]

        let sections = SignGroupingHelper.groupByFirstLetter(signs)

        XCTAssertEqual(sections.map(\.letter), ["А", "Б"])
        XCTAssertEqual(sections[0].signs.map(\.word), ["Аист", "Арбуз"])
    }

    func testGroupByFirstLetterUsesHashForInvalidLeadingCharacters() {
        let signs = [
            makeSign(id: "1", word: "1Жест"),
            makeSign(id: "2", word: "😀Эмоция"),
            makeSign(id: "3", word: "")
        ]

        let sections = SignGroupingHelper.groupByFirstLetter(signs)

        XCTAssertEqual(sections.map(\.letter), ["#"])
        XCTAssertEqual(sections.first?.signs.count, 3)
    }

    func testGroupByFirstLetterSupportsDescendingOrder() {
        let signs = [
            makeSign(id: "1", word: "Арбуз"),
            makeSign(id: "2", word: "Борщ"),
            makeSign(id: "3", word: "Вилка")
        ]

        let sections = SignGroupingHelper.groupByFirstLetter(signs, sortOrder: .descending)

        XCTAssertEqual(sections.map(\.letter), ["В", "Б", "А"])
    }

    func testGroupByFirstLetterKeepsHashSectionLastInDescendingOrder() {
        let signs = [
            makeSign(id: "1", word: "Арбуз"),
            makeSign(id: "2", word: "1Жест"),
            makeSign(id: "3", word: "Борщ")
        ]

        let sections = SignGroupingHelper.groupByFirstLetter(signs, sortOrder: .descending)

        XCTAssertEqual(sections.map(\.letter), ["Б", "А", "#"])
    }

    func testGroupByFirstLetterDoesNotProduceEmptySections() {
        let signs = [
            makeSign(id: "1", word: "Арбуз")
        ]

        let sections = SignGroupingHelper.groupByFirstLetter(signs)

        XCTAssertTrue(sections.allSatisfy { !$0.signs.isEmpty })
    }

    private func makeSign(id: String, word: String) -> Sign {
        Sign(
            id: id,
            word: word,
            description: "Описание",
            categoryId: "category-1",
            videos: [TestFixtures.video],
            synonyms: nil
        )
    }
}
