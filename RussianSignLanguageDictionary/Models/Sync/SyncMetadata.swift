import Foundation

/// Метаданные синхронизации данных
struct SyncMetadata: Codable {
    /// Дата последнего обновления на сервере
    let lastUpdated: Date
    
    /// Флаг наличия обновлений
    let hasUpdates: Bool
}
