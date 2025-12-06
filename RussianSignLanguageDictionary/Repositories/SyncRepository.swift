import Foundation
import os.log

/// Репозиторий для синхронизации данных с сервером
final class SyncRepository: SyncRepositoryProtocol {
    // MARK: - Properties
    
    private let baseURL: URL
    private let session: URLSession
    private let logger = Logger(subsystem: "com.rsl.SyncRepository", category: "sync")
    
    // MARK: - Initialization
    
    init(baseURL: URL = APIConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    // MARK: - Private Helpers
    
    /// Создает форматтер даты ISO8601 с дробными секундами
    private static func createDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
    
    /// Статический форматтер даты для переиспользования
    private static let dateFormatter = createDateFormatter()
    
    /// Создает JSONDecoder с настройкой парсинга даты для бекенда
    /// Бекенд гарантирует формат ISO 8601 с суффиксом 'Z' (UTC)
    private func createDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Формат теперь стандартизирован: ISO8601 с 'Z' суффиксом
            guard let date = Self.dateFormatter.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date format: \(dateString). Expected ISO8601 with 'Z' suffix."
                )
            }
            return date
        }
        // НЕ используем convertFromSnakeCase, так как все структуры используют явные CodingKeys
        // decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
    
    /// Создает URL для проверки обновлений
    private func buildCheckUpdatesURL(lastUpdated: Date?) -> URL? {
        let endpointURL = baseURL.appendingPathComponent("sync").appendingPathComponent("check")
        var urlComponents = URLComponents(
            url: endpointURL,
            resolvingAgainstBaseURL: false
        )!
        
        if let lastUpdated = lastUpdated {
            urlComponents.queryItems = [
                URLQueryItem(name: "last_updated", value: Self.dateFormatter.string(from: lastUpdated))
            ]
        }
        
        return urlComponents.url
        }
        
    /// Выполняет сетевой запрос
    private func performNetworkRequest(url: URL) async throws -> (Data, HTTPURLResponse) {
        logger.info("🔄 Запрос к URL: \(url.absoluteString, privacy: .public)")
        
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SyncError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
            logger.error("❌ Ошибка сервера: \(httpResponse.statusCode)")
                throw SyncError.serverError(httpResponse.statusCode)
            }
        
        return (data, httpResponse)
    }
    
    /// Декодирует ответ в указанный тип
    private func decodeResponse<T: Codable>(data: Data, type: T.Type) throws -> T {
        let decoder = createDecoder()
        
        do {
            return try decoder.decode(SyncResponse<T>.self, from: data).data
        } catch let decodingError as DecodingError {
            logDecodingError(decodingError, data: data)
            throw SyncError.decodingError(decodingError)
        }
    }
    
    /// Логирует ошибку декодирования с детальной информацией
    private func logDecodingError(_ error: DecodingError, data: Data) {
        logger.error("❌ Ошибка декодирования: \(error.localizedDescription)")
        
        if case .keyNotFound(let key, let context) = error {
            logger.error("   Отсутствует ключ: \(key.stringValue)")
            logger.error("   Путь: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        }
        
        if case .dataCorrupted(let context) = error {
            logger.error("   Проблема с данными: \(context.debugDescription)")
        }
        
        // Попробуем декодировать как словарь для отладки
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataDict = dict["data"] as? [String: Any] {
            logger.debug("   Ключи в data: \(dataDict.keys.joined(separator: ", "))")
        }
    }
    
    /// Обрабатывает сетевую ошибку и преобразует в SyncError
    private func handleNetworkError(_ error: Error) throws -> SyncError {
        if let urlError = error as? URLError {
            if urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                logger.warning("⚠️ Нет подключения к интернету")
                return SyncError.noInternet
            }
            logger.error("❌ Ошибка сети: \(urlError.localizedDescription)")
            return SyncError.networkError(urlError)
        }
        
        if let syncError = error as? SyncError {
            return syncError
        }
        
        logger.error("❌ Неизвестная ошибка: \(error.localizedDescription)")
        return SyncError.networkError(error)
    }
    
    // MARK: - SyncRepositoryProtocol
    
    func checkForUpdates(lastUpdated: Date?) async throws -> SyncMetadata {
        guard let url = buildCheckUpdatesURL(lastUpdated: lastUpdated) else {
            throw SyncError.invalidResponse
        }
        
        var responseData: Data?
        
        do {
            let (data, _) = try await performNetworkRequest(url: url)
            responseData = data
            
            // Логируем сырой ответ для отладки
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("📥 Ответ checkForUpdates: \(responseString.prefix(200), privacy: .public)")
            }
            
            let decoder = createDecoder()
                let syncResponse = try decoder.decode(SyncResponse<SyncMetadata>.self, from: data)
                
                guard syncResponse.success else {
                    throw SyncError.invalidResponse
                }
                
                return syncResponse.data
        } catch let error as DecodingError {
            logDecodingError(error, data: responseData ?? Data())
            throw SyncError.decodingError(error)
        } catch {
            throw try handleNetworkError(error)
        }
    }
    
    func fetchAllData() async throws -> SyncData {
        let url = baseURL.appendingPathComponent("sync").appendingPathComponent("data")
        
        var responseData: Data?
        
        do {
            let (data, _) = try await performNetworkRequest(url: url)
            responseData = data
            
            // Логируем первые знаки ответа для отладки
            if let responseString = String(data: data, encoding: .utf8) {
                let preview = responseString.prefix(500)
                logger.debug("📥 Начало ответа fetchAllData: \(preview, privacy: .public)...")
            }
            
            let decoder = createDecoder()
            let syncResponse = try decoder.decode(SyncResponse<SyncDataResponse>.self, from: data)
            
                return SyncData(
                    categories: syncResponse.data.categories,
                    signs: syncResponse.data.signs,
                    lastUpdated: syncResponse.data.lastUpdated
                )
        } catch let error as DecodingError {
            logDecodingError(error, data: responseData ?? Data())
            throw SyncError.decodingError(error)
        } catch {
            throw try handleNetworkError(error)
        }
    }
}
