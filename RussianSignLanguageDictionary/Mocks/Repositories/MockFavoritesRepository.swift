import Foundation

#if DEBUG
/// Mock реализация FavoritesRepositoryProtocol для превью и тестов
final class MockFavoritesRepository: FavoritesRepositoryProtocol {
    // MARK: - Properties
    
    /// Хранилище избранных жестов
    private var favorites: Set<String> = []
    
    // MARK: - Init
    
    init(initialFavorites: [String] = []) {
        self.favorites = Set(initialFavorites)
    }
    
    // MARK: - FavoritesRepositoryProtocol
    
    func getFavorites() -> [String] {
        return Array(favorites)
    }
    
    func addFavorite(signId: String) {
        favorites.insert(signId)
    }
    
    func removeFavorite(signId: String) {
        favorites.remove(signId)
    }
    
    func isFavorite(signId: String) -> Bool {
        return favorites.contains(signId)
    }
    
    func clearAllFavorites() {
        favorites.removeAll()
    }
}

// MARK: - Shared Instances

extension MockFavoritesRepository {
    /// Общий экземпляр для использования в Preview с предустановленными данными
    static let shared: MockFavoritesRepository = {
        let repo = MockFavoritesRepository()
        repo.addFavorite(signId: "sign_001")
        repo.addFavorite(signId: "sign_002")
        repo.addFavorite(signId: "sign_003")
        return repo
    }()
    
    /// Пустой экземпляр для Preview без избранного
    static let empty = MockFavoritesRepository()
}
#endif
