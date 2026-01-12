import Foundation

/// Протокол репозитория для синхронизации данных с сервером
protocol SyncRepositoryProtocol {
    /// Проверяет наличие обновлений на сервере
    /// - Parameter lastUpdated: Дата последнего обновления на клиенте (опционально)
    /// - Returns: Метаданные синхронизации
    /// - Throws: SyncError в случае ошибки
    func checkForUpdates(lastUpdated: Date?) async throws -> SyncMetadata
    
    /// Загружает все данные с сервера
    /// - Returns: Данные синхронизации (категории, жесты, дата обновления)
    /// - Throws: SyncError в случае ошибки
    func fetchAllData() async throws -> SyncData
}

/// Данные синхронизации с сервера (Raw API)
/// Raw API возвращает данные напрямую без обертки {success, data}
struct SyncData: Codable {
    /// Массив категорий
    let categories: [Category]
    
    /// Массив жестов
    let signs: [Sign]
    
    /// Дата последнего обновления (Unix timestamp)
    let lastUpdated: Date
}

// MARK: - Legacy Support (для обратной совместимости с кешем)

/// Структура ответа API (Legacy - deprecated)
/// Используется только для чтения старого кеша, новые данные используют Raw API
struct SyncResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let message: String?
}
