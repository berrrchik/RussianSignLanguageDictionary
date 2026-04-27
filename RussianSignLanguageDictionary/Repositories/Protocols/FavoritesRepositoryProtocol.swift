import Foundation

/// Протокол репозитория для работы с избранными жестами через UserDefaults
@MainActor
protocol FavoritesRepositoryProtocol {
    /// Получает список ID избранных жестов
    /// - Returns: Массив идентификаторов избранных жестов
    func getFavorites() -> [String]

    /// Получает расширенные записи избранного со snapshot и offline-статусом
    /// - Returns: Массив записей избранного в порядке добавления
    func getFavoriteEntries() -> [FavoriteEntry]

    /// Возвращает snapshot избранного жеста для офлайн-восстановления
    /// - Parameter signId: ID жеста
    func cachedFavoriteSnapshot(signId: String) -> FavoriteSignSnapshot?

    /// Возвращает избранные записи, требующие повторной подготовки офлайн-видео
    func failedFavoriteEntries() -> [FavoriteEntry]

    /// Пересчитывает офлайн-готовность по реальным файлам на диске
    func reconcileOfflineState() async
    
    /// Добавляет жест в избранное
    /// - Parameter signId: Идентификатор жеста
    func addFavorite(signId: String)

    /// Добавляет жест в избранное и сохраняет его snapshot для офлайн-списка
    /// - Parameters:
    ///   - sign: Жест для сохранения
    ///   - categoryName: Название категории для офлайн-рендеринга
    func addFavorite(sign: Sign, categoryName: String)

    /// Обновляет сохранённый snapshot избранного жеста
    /// - Parameters:
    ///   - sign: Актуальная модель жеста
    ///   - categoryName: Название категории
    func updateFavoriteSnapshot(sign: Sign, categoryName: String)

    /// Обновляет состояние офлайн-подготовки для избранного жеста
    /// - Parameters:
    ///   - signId: ID жеста
    ///   - status: Новый статус подготовки
    ///   - downloadedVideoIds: ID уже подготовленных видео
    ///   - requiredVideoIds: Полный список обязательных видео
    func updateOfflineStatus(
        signId: String,
        status: FavoriteOfflineStatus,
        downloadedVideoIds: [Int],
        requiredVideoIds: [Int]
    )
    
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

extension FavoritesRepositoryProtocol {
    func getFavoriteEntry(signId: String) -> FavoriteEntry? {
        getFavoriteEntries().first { $0.signId == signId }
    }
}
