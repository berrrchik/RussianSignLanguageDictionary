import Foundation

/// Протокол для синхронизации данных с сервером
protocol SyncRepositoryProtocol {
    /// Проверяет наличие обновлений на сервере
    func checkForUpdates(lastUpdated: Date?) async throws -> SyncMetadata
    
    /// Загружает все данные с сервера
    /// - Parameter cachedDataProvider: Провайдер кешированных данных для 304 Not Modified
    func fetchAllData(cachedDataProvider: @escaping () throws -> SyncData) async throws -> SyncData
}
