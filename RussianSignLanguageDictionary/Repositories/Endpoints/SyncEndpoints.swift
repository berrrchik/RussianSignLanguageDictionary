import Foundation

/// Эндпоинты синхронизации с Raw API
/// Централизованное построение URL для SyncRepository
enum SyncEndpoints {
    /// Проверка наличия обновлений
    case checkUpdates(lastUpdated: Date?)
    /// Загрузка всех данных
    case fetchData
    
    // MARK: - URL Building
    
    /// Строит URL для эндпоинта
    /// - Parameter baseURL: Базовый URL API
    /// - Returns: Готовый URL для запроса
    func url(baseURL: URL) -> URL {
        switch self {
        case .checkUpdates(let lastUpdated):
            return buildCheckUpdatesURL(baseURL: baseURL, lastUpdated: lastUpdated)
        case .fetchData:
            return buildFetchDataURL(baseURL: baseURL)
        }
    }
    
    // MARK: - Private Methods
    
    private func buildCheckUpdatesURL(baseURL: URL, lastUpdated: Date?) -> URL {
        let endpointURL = baseURL
            .appendingPathComponent("sync")
            .appendingPathComponent("check")
            .appendingPathComponent("raw")
        
        guard var urlComponents = URLComponents(
            url: endpointURL,
            resolvingAgainstBaseURL: false
        ) else {
            return endpointURL
        }
        
        if let lastUpdated = lastUpdated {
            let timestamp = Int(lastUpdated.timeIntervalSince1970)
            urlComponents.queryItems = [
                URLQueryItem(name: "last_updated", value: String(timestamp))
            ]
        }
        
        return urlComponents.url ?? endpointURL
    }
    
    private func buildFetchDataURL(baseURL: URL) -> URL {
        baseURL
            .appendingPathComponent("sync")
            .appendingPathComponent("data")
            .appendingPathComponent("raw")
    }
}
