import Foundation
import Combine

/// Репозиторий для работы с избранными жестами через UserDefaults
final class FavoritesRepository: FavoritesRepositoryProtocol, ObservableObject {
    // MARK: - Properties
    
    /// Ключ для хранения избранного в UserDefaults
    private let favoritesKey = "com.rsl.favorites"
    
    /// UserDefaults для хранения данных
    private let userDefaults: UserDefaults
    
    /// Publisher для изменений избранного
    @Published private(set) var favoritesPublisher: [String] = []
    
    // MARK: - Initialization
    
    /// Инициализатор репозитория
    /// - Parameter userDefaults: UserDefaults (по умолчанию .standard)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.favoritesPublisher = self.getFavorites()
    }
    
    // MARK: - FavoritesRepositoryProtocol
    
    func getFavorites() -> [String] {
        // UserDefaults.standard является thread-safe для чтения
        // Поэтому можем безопасно читать с любого потока
        return userDefaults.stringArray(forKey: favoritesKey) ?? []
    }
    
    func addFavorite(signId: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.addFavorite(signId: signId)
            }
            return
        }
        
        var favorites = getFavorites()
        
        guard !favorites.contains(signId) else {
            return
        }
        
        favorites.append(signId)
        userDefaults.set(favorites, forKey: favoritesKey)
        
        favoritesPublisher = favorites
    }
    
    func removeFavorite(signId: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.removeFavorite(signId: signId)
            }
            return
        }
        
        var favorites = getFavorites()
        favorites.removeAll { $0 == signId }
        
        userDefaults.set(favorites, forKey: favoritesKey)
        
        favoritesPublisher = favorites
    }
    
    func isFavorite(signId: String) -> Bool {
        let favorites = getFavorites()
        return favorites.contains(signId)
    }
    
    func clearAllFavorites() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.clearAllFavorites()
            }
            return
        }
        
        userDefaults.removeObject(forKey: favoritesKey)
        
        favoritesPublisher = []
    }
}

