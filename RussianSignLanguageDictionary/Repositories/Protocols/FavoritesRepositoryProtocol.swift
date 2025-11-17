import Foundation

/// Протокол репозитория для работы с избранными жестами через UserDefaults
protocol FavoritesRepositoryProtocol {
    /// Получает список ID избранных жестов
    /// - Returns: Массив идентификаторов избранных жестов
    func getFavorites() -> [String]
    
    /// Добавляет жест в избранное
    /// - Parameter signId: Идентификатор жеста
    func addFavorite(signId: String)
    
    /// Удаляет жест из избранного
    /// - Parameter signId: Идентификатор жеста
    func removeFavorite(signId: String)
    
    /// Проверяет, находится ли жест в избранном
    /// - Parameter signId: Идентификатор жеста
    /// - Returns: true, если жест в избранном, иначе false
    func isFavorite(signId: String) -> Bool
    
    /// Очищает весь список избранного
    func clearAllFavorites()
}

