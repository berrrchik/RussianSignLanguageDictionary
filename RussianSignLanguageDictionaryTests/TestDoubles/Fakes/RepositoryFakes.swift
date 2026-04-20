import Foundation
import Combine
@testable import RussianSignLanguageDictionary

final class SignRepositoryFake: SignRepositoryProtocol {
    private(set) var signsById: [String: Sign]
    private(set) var categoriesById: [String: AppCategory]
    private let cachedSignsStorage: [Sign]?
    private let dataUpdatedSubject = PassthroughSubject<SyncData, Never>()

    init(
        signs: [Sign] = [TestFixtures.sign],
        categories: [AppCategory] = [TestFixtures.category],
        cachedSigns: [Sign]? = nil
    ) {
        self.signsById = Dictionary(uniqueKeysWithValues: signs.map { ($0.id, $0) })
        self.categoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        self.cachedSignsStorage = cachedSigns
    }

    var dataUpdatedPublisher: AnyPublisher<SyncData, Never> {
        dataUpdatedSubject.eraseToAnyPublisher()
    }

    func loadAllSigns() async throws -> [Sign] {
        Array(signsById.values).sorted { $0.word < $1.word }
    }

    func loadCategories() async throws -> [AppCategory] {
        Array(categoriesById.values).sorted { $0.order < $1.order }
    }

    func getSign(byId id: String) async throws -> Sign? {
        signsById[id]
    }

    func getSigns(byCategory categoryId: String) async throws -> [Sign] {
        signsById.values.filter { $0.categoryId == categoryId }.sorted { $0.word < $1.word }
    }

    func searchSigns(query: String) async throws -> [Sign] {
        guard !query.isEmpty else { return [] }
        return signsById.values.filter { $0.word.localizedCaseInsensitiveContains(query) }.sorted { $0.word < $1.word }
    }

    func cachedSigns() -> [Sign]? {
        cachedSignsStorage
    }
}

final class FavoritesRepositoryFake: FavoritesRepositoryProtocol {
    private var favorites = Set<String>()

    init(initialFavorites: [String] = []) {
        favorites = Set(initialFavorites)
    }

    func getFavorites() -> [String] {
        Array(favorites).sorted()
    }

    func addFavorite(signId: String) {
        favorites.insert(signId)
    }

    func removeFavorite(signId: String) {
        favorites.remove(signId)
    }

    func isFavorite(signId: String) -> Bool {
        favorites.contains(signId)
    }

    func clearAllFavorites() {
        favorites.removeAll()
    }
}
