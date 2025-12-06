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

/// Данные синхронизации с сервера
struct SyncData: Codable {
    /// Массив категорий
    let categories: [Category]
    
    /// Массив жестов
    let signs: [Sign]
    
    /// Дата последнего обновления
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case categories, signs
        case lastUpdated = "last_updated"
    }
}

/// Структура ответа API
struct SyncResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let message: String?
}

/// Структура ответа данных синхронизации из API
struct SyncDataResponse: Codable {
    let categories: [Category]
    let signs: [Sign]
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case categories, signs
        case lastUpdated = "last_updated"
    }
}
