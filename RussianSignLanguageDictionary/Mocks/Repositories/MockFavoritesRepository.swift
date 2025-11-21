import Foundation

#if DEBUG
extension FavoritesRepository {
    /// Shared mock экземпляр для Preview с предустановленными данными
    static let preview: FavoritesRepository = {
        let defaults = UserDefaults(suiteName: "preview.favorites")!
        let repo = FavoritesRepository(userDefaults: defaults)
        
        // Добавляем тестовые избранные жесты
        repo.addFavorite(signId: "sign_001")
        repo.addFavorite(signId: "sign_002")
        repo.addFavorite(signId: "sign_003")
        
        return repo
    }()
    
    /// Пустой mock экземпляр для Preview без избранного
    static let previewEmpty: FavoritesRepository = {
        let defaults = UserDefaults(suiteName: "preview.favorites.empty")!
        return FavoritesRepository(userDefaults: defaults)
    }()
}
#endif

