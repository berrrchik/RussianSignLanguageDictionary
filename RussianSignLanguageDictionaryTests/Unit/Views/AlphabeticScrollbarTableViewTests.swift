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

    func testCoordinatorShowsReadyOfflineIconNextToSignTitle() {
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
            favoriteOfflineStatusProvider: { _ in .readyOffline },
            onSignSelected: { _ in }
        )
        let coordinator = tableViewWrapper.makeCoordinator()
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(SignRowTableViewCell.self, forCellReuseIdentifier: "SignCell")

        let cell = coordinator.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0))

        XCTAssertTrue(imageIdentifiers(in: cell).contains("offline-status-arrow.down.to.line.compact"))
    }

    func testCoordinatorShowsFailedOfflineIconNextToSignTitle() {
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
            favoriteOfflineStatusProvider: { _ in .failed },
            onSignSelected: { _ in }
        )
        let coordinator = tableViewWrapper.makeCoordinator()
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(SignRowTableViewCell.self, forCellReuseIdentifier: "SignCell")

        let cell = coordinator.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0))

        XCTAssertTrue(imageIdentifiers(in: cell).contains("offline-status-exclamationmark.circle"))
    }

    func testCoordinatorConfiguresCell_ExposesSingleAccessibilityElementWithWordAndCategory() {
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

        XCTAssertEqual(cell.contentView.accessibilityLabel, "Привет, Категория 1")
        XCTAssertTrue(accessibleSubviews(of: cell.contentView).isEmpty)
    }

    func testCoordinatorCleanupClearsTableState() {
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
            favoriteOfflineStatusProvider: { _ in .readyOffline },
            onSignSelected: { _ in }
        )
        let coordinator = tableViewWrapper.makeCoordinator()
        let tableView = UITableView(frame: .zero, style: .plain)
        coordinator.tableView = tableView

        coordinator.cleanup()

        XCTAssertTrue(coordinator.sections.isEmpty)
        XCTAssertNil(coordinator.favoritesRepository)
        XCTAssertNil(coordinator.favoriteOfflineStatusProvider)
        XCTAssertNil(coordinator.tableView)
    }

    func testTrailingSwipeActionsReturnsNilWhenNoDeleteHandlerProvided() {
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
            categoryNamesById: [:],
            favoriteOfflineStatusProvider: nil,
            onSignSelected: { _ in }
        )
        let coordinator = tableViewWrapper.makeCoordinator()
        let tableView = UITableView(frame: .zero, style: .plain)

        let configuration = coordinator.tableView(tableView, trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0))

        XCTAssertNil(configuration)
    }

    func testTrailingSwipeActionInvokesOnDeleteSignWithCorrectSign() {
        let sign = Sign(
            id: "sign-1",
            word: "Привет",
            description: "Тестовый жест",
            categoryId: "category-1",
            videos: [TestFixtures.video],
            synonyms: nil
        )
        var deletedSign: Sign?
        let tableViewWrapper = AlphabeticScrollbarTableView(
            sections: [
                SearchViewModel.SignSection(id: "section-a", letter: "П", signs: [sign])
            ],
            favoritesRepository: nil,
            categoryNamesById: [:],
            favoriteOfflineStatusProvider: nil,
            onSignSelected: { _ in },
            onDeleteSign: { deletedSign = $0 }
        )
        let coordinator = tableViewWrapper.makeCoordinator()
        let tableView = UITableView(frame: .zero, style: .plain)

        let configuration = coordinator.tableView(tableView, trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0))
        let action = configuration?.actions.first

        XCTAssertEqual(action?.style, .destructive)
        action?.handler(action!, UIView()) { _ in }

        XCTAssertEqual(deletedSign?.id, "sign-1")
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

    private func accessibleSubviews(of view: UIView) -> [UIView] {
        var elements: [UIView] = []

        for subview in view.subviews {
            if subview.isAccessibilityElement {
                elements.append(subview)
            }
            elements.append(contentsOf: accessibleSubviews(of: subview))
        }

        return elements
    }

    private func imageIdentifiers(in view: UIView) -> [String] {
        var identifiers: [String] = []

        if let imageView = view as? UIImageView, let identifier = imageView.accessibilityIdentifier {
            identifiers.append(identifier)
        }

        for subview in view.subviews {
            identifiers.append(contentsOf: imageIdentifiers(in: subview))
        }

        return identifiers
    }
}
