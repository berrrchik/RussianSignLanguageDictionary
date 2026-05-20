import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class CategoryDetailViewModelTests: XCTestCase {
    private var signRepository: SignRepositorySpy!
    private var sut: CategoryDetailViewModel!
    private var category: AppCategory!

    override func setUp() {
        super.setUp()
        signRepository = SignRepositorySpy()
        category = makeCategory(id: "category-1", name: "Общение", order: 1)
        sut = CategoryDetailViewModel(category: category, signRepository: signRepository)
    }

    override func tearDown() {
        sut = nil
        category = nil
        signRepository = nil
        super.tearDown()
    }

    func testInitialStateContainsProvidedCategory() {
        XCTAssertEqual(sut.category.id, "category-1")
        XCTAssertEqual(sut.category.name, "Общение")
        XCTAssertEqual(sut.signs, [])
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.categoryNamesById["category-1"], "Общение")
    }

    func testLoadSignsRequestsSignsForCategoryId() async {
        signRepository.getSignsByCategoryResult = .success([])
        signRepository.loadCategoriesResult = .success([category])

        await sut.loadSigns()

        XCTAssertEqual(signRepository.getSignsByCategoryArguments, ["category-1"])
    }

    func testLoadSignsLoadsCategories() async {
        signRepository.getSignsByCategoryResult = .success([])
        signRepository.loadCategoriesResult = .success([category])

        await sut.loadSigns()

        XCTAssertEqual(signRepository.loadCategoriesCallCount, 1)
    }

    func testLoadSignsAppliesLoadedSignsCategoryNamesAndState() async {
        let signs = [
            makeSign(id: "sign-1", word: "Привет", categoryId: "category-1"),
            makeSign(id: "sign-2", word: "Пока", categoryId: "category-1")
        ]
        signRepository.getSignsByCategoryResult = .success(signs)
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-2", name: "Другое", order: 2),
            category
        ])

        await sut.loadSigns()

        XCTAssertEqual(sut.signs.map(\.id), ["sign-1", "sign-2"])
        XCTAssertEqual(sut.categoryNamesById["category-1"], "Общение")
        XCTAssertEqual(sut.categoryNamesById["category-2"], "Другое")
        XCTAssertEqual(sut.state, .loaded)
    }

    func testLoadSignsMapsSignRepositoryError() async {
        signRepository.getSignsByCategoryResult = .failure(SignRepositoryError.fileNotFound)

        await sut.loadSigns()

        XCTAssertEqual(sut.signs, [])
        XCTAssertEqual(sut.state, .error("Не удалось загрузить данные"))
    }

    func testLoadSignsMapsGenericError() async {
        signRepository.getSignsByCategoryResult = .failure(NSError(domain: "test", code: 7))

        await sut.loadSigns()

        if case .error(let message) = sut.state {
            XCTAssertTrue(message.hasPrefix("Произошла ошибка:"))
        } else {
            XCTFail("Expected error state")
        }
    }

    func testRepositoryUpdatesOnlyKeepSignsForCurrentCategory() async {
        signRepository.dataUpdatedSubject.send(
            SyncData(
                categories: [
                    category,
                    makeCategory(id: "category-2", name: "Другое", order: 2)
                ],
                signs: [
                    makeSign(id: "sign-1", word: "Привет", categoryId: "category-1"),
                    makeSign(id: "sign-2", word: "Алфавит", categoryId: "category-2"),
                    makeSign(id: "sign-3", word: "Пока", categoryId: "category-1")
                ],
                lessons: [],
                lastUpdated: Date()
            )
        )

        let didUpdate = await waitUntil {
            self.sut.signs.map(\.id) == ["sign-1", "sign-3"]
        }

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(sut.signs.map(\.id), ["sign-1", "sign-3"])
        XCTAssertEqual(sut.state, .loaded)
    }

    func testGroupedSignsGroupsLoadedSignsByFirstLetter() async {
        signRepository.getSignsByCategoryResult = .success([
            makeSign(id: "sign-1", word: "Привет", categoryId: "category-1"),
            makeSign(id: "sign-2", word: "Пока", categoryId: "category-1"),
            makeSign(id: "sign-3", word: "Спасибо", categoryId: "category-1")
        ])
        signRepository.loadCategoriesResult = .success([category])

        await sut.loadSigns()

        XCTAssertEqual(sut.groupedSigns.map(\.letter), ["П", "С"])
        XCTAssertEqual(sut.groupedSigns[0].signs.map(\.id), ["sign-2", "sign-1"])
        XCTAssertEqual(sut.groupedSigns[1].signs.map(\.id), ["sign-3"])
    }

    private func makeCategory(id: String, name: String, order: Int) -> AppCategory {
        AppCategory(
            id: id,
            name: name,
            order: order,
            signCount: 1,
            icon: nil,
            color: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func makeSign(id: String, word: String, categoryId: String) -> Sign {
        Sign(
            id: id,
            word: word,
            description: "Описание \(word)",
            categoryId: categoryId,
            videos: [TestFixtures.video],
            synonyms: nil
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
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
}
