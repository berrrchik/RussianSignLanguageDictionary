import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class FavoritesViewModelTests: XCTestCase {
    private var sut: FavoritesViewModel!
    private var favoritesRepository: FavoritesRepositorySpy!
    private var signRepository: SignRepositorySpy!

    override func setUp() {
        super.setUp()
        favoritesRepository = FavoritesRepositorySpy()
        signRepository = SignRepositorySpy()
        sut = FavoritesViewModel(
            favoritesRepository: favoritesRepository,
            signRepository: signRepository
        )
    }

    override func tearDown() {
        sut = nil
        favoritesRepository = nil
        signRepository = nil
        super.tearDown()
    }

    func testLoadFavoritesLoadsSignsInFavoritesOrder() async {
        favoritesRepository.favorites = ["sign-2", "sign-1"]
        signRepository.loadAllSignsResult = .success([
            makeSign(id: "sign-1", word: "Буква"),
            makeSign(id: "sign-2", word: "Арбуз")
        ])
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-1", name: "Категория 1", order: 1)
        ])

        await sut.loadFavorites()

        XCTAssertEqual(sut.favoriteSigns.map(\.id), ["sign-2", "sign-1"])
        XCTAssertEqual(sut.categoryNamesById["category-1"], "Категория 1")
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadFavoritesReturnsEmptyStateWhenFavoritesListIsEmpty() async {
        favoritesRepository.favorites = []

        await sut.loadFavorites()

        XCTAssertEqual(sut.favoriteSigns, [])
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(signRepository.loadAllSignsCallCount, 0)
    }

    func testLoadFavoritesShowsTemporaryErrorForMissingSigns() async {
        favoritesRepository.favorites = ["sign-1", "missing"]
        signRepository.loadAllSignsResult = .success([
            makeSign(id: "sign-1", word: "Привет")
        ])
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-1", name: "Категория 1", order: 1)
        ])

        await sut.loadFavorites()

        XCTAssertEqual(sut.favoriteSigns.map(\.id), ["sign-1"])
        XCTAssertEqual(sut.errorMessage, "Не удалось загрузить 1 жестов")
    }

    func testLoadFavoritesMapsRepositoryError() async {
        favoritesRepository.favorites = ["sign-1"]
        signRepository.loadAllSignsResult = .failure(SignRepositoryError.noDataAvailable)

        await sut.loadFavorites()

        XCTAssertEqual(
            sut.errorMessage,
            "Для первого запуска приложения необходимо подключение к интернету. После загрузки данных приложение будет работать офлайн."
        )
        XCTAssertFalse(sut.isLoading)
    }

    func testRemoveFavoriteUpdatesRepositoryAndState() async {
        favoritesRepository.favorites = ["sign-1", "sign-2"]
        signRepository.loadAllSignsResult = .success([
            makeSign(id: "sign-1", word: "Привет"),
            makeSign(id: "sign-2", word: "Пока")
        ])
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-1", name: "Категория 1", order: 1)
        ])

        await sut.loadFavorites()

        sut.removeFavorite(signId: "sign-1")

        XCTAssertEqual(favoritesRepository.removeFavoriteCalls, ["sign-1"])
        XCTAssertEqual(sut.favoriteSigns.map(\.id), ["sign-2"])
    }

    func testClearAllFavoritesClearsRepositoryAndState() async {
        favoritesRepository.favorites = ["sign-1"]
        signRepository.loadAllSignsResult = .success([makeSign(id: "sign-1", word: "Привет")])
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-1", name: "Категория 1", order: 1)
        ])

        await sut.loadFavorites()

        sut.clearAllFavorites()

        XCTAssertEqual(favoritesRepository.clearAllFavoritesCallCount, 1)
        XCTAssertEqual(sut.favoriteSigns, [])
    }

    func testIsFavoriteDelegatesToRepository() {
        favoritesRepository.favoriteLookup["sign-1"] = true

        XCTAssertTrue(sut.isFavorite(signId: "sign-1"))
        XCTAssertEqual(favoritesRepository.isFavoriteCalls, ["sign-1"])
    }

    func testSortOptionAlphabeticalAscendingSortsByWord() async {
        favoritesRepository.favorites = ["sign-1", "sign-2"]
        signRepository.loadAllSignsResult = .success([
            makeSign(id: "sign-1", word: "Яблоко"),
            makeSign(id: "sign-2", word: "Арбуз")
        ])
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-1", name: "Категория 1", order: 1)
        ])

        await sut.loadFavorites()
        sut.sortOption = .alphabeticalAsc

        XCTAssertEqual(sut.favoriteSigns.map(\.word), ["Арбуз", "Яблоко"])
    }

    func testSortOptionAlphabeticalDescendingSortsByWord() async {
        favoritesRepository.favorites = ["sign-1", "sign-2"]
        signRepository.loadAllSignsResult = .success([
            makeSign(id: "sign-1", word: "Арбуз"),
            makeSign(id: "sign-2", word: "Яблоко")
        ])
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-1", name: "Категория 1", order: 1)
        ])

        await sut.loadFavorites()
        sut.sortOption = .alphabeticalDesc

        XCTAssertEqual(sut.favoriteSigns.map(\.word), ["Яблоко", "Арбуз"])
    }

    func testSortOptionDateAddedAscendingReversesLoadedOrder() async {
        favoritesRepository.favorites = ["sign-2", "sign-1"]
        signRepository.loadAllSignsResult = .success([
            makeSign(id: "sign-1", word: "Арбуз"),
            makeSign(id: "sign-2", word: "Яблоко")
        ])
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-1", name: "Категория 1", order: 1)
        ])

        await sut.loadFavorites()
        sut.sortOption = .dateAddedAsc

        XCTAssertEqual(sut.favoriteSigns.map(\.id), ["sign-1", "sign-2"])
    }

    func testSortOptionDateAddedDescendingKeepsLoadedOrder() async {
        favoritesRepository.favorites = ["sign-2", "sign-1"]
        signRepository.loadAllSignsResult = .success([
            makeSign(id: "sign-1", word: "Арбуз"),
            makeSign(id: "sign-2", word: "Яблоко")
        ])
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "category-1", name: "Категория 1", order: 1)
        ])

        await sut.loadFavorites()
        sut.sortOption = .dateAddedDesc

        XCTAssertEqual(sut.favoriteSigns.map(\.id), ["sign-2", "sign-1"])
    }

    func testRepositoryUpdatesRefreshCategoryNamesForFavorites() async {
        favoritesRepository.favorites = ["sign-1"]
        signRepository.dataUpdatedSubject.send(
            SyncData(
                categories: [makeCategory(id: "category-1", name: "Обновлённая", order: 1)],
                signs: [makeSign(id: "sign-1", word: "Привет")],
                lessons: [],
                lastUpdated: Date()
            )
        )

        let didUpdate = await waitUntil {
            self.sut.favoriteSigns.map(\.id) == ["sign-1"]
                && self.sut.categoryNamesById["category-1"] == "Обновлённая"
        }

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(sut.favoriteSigns.map(\.id), ["sign-1"])
        XCTAssertEqual(sut.categoryNamesById["category-1"], "Обновлённая")
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
