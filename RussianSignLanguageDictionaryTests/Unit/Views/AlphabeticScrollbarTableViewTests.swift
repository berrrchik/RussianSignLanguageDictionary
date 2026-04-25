import XCTest
import UIKit
@testable import RussianSignLanguageDictionary

@MainActor
final class AlphabeticScrollbarTableViewTests: XCTestCase {
    func testCoordinatorConfiguresCellWithPreparedCategoryName() {
        let sign = Sign(
            id: "sign-1",
            word: "Привет",
            description: "Тестовый жест",
            categoryId: "category-1",
            videos: [TestFixtures.video],
            synonyms: nil
        )
        let tableViewWrapper = AlphabeticScrollbarTableView(
            sections: [
                SearchViewModel.SignSection(id: "section-a", letter: "П", signs: [sign])
            ],
            favoritesRepository: nil,
            categoryNamesById: ["category-1": "Категория 1"],
            favoriteOfflineStatusProvider: nil,
            onSignSelected: { _ in }
        )
        let coordinator = tableViewWrapper.makeCoordinator()
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(SignRowTableViewCell.self, forCellReuseIdentifier: "SignCell")

        let cell = coordinator.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0))

        XCTAssertTrue(viewHierarchy(of: cell).contains("Категория 1"))
    }

    private func viewHierarchy(of view: UIView) -> [String] {
        var texts: [String] = []

        if let label = view as? UILabel, let text = label.text {
            texts.append(text)
        }

        for subview in view.subviews {
            texts.append(contentsOf: viewHierarchy(of: subview))
        }

        return texts
    }
}
