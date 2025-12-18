import Foundation
import os.log

/// Репозиторий для синхронизации данных с сервером
final class SyncRepository: SyncRepositoryProtocol {
    // MARK: - Properties
    
    private let baseURL: URL
    private let session: URLSession
    private let logger = Logger(subsystem: "com.rsl.SyncRepository", category: "sync")
    
    // MARK: - Initialization
    
    init(baseURL: URL = APIConfig.baseURL, session: URLSession? = nil) {
        self.baseURL = baseURL
        
        // Создаем URLSession с разумными таймаутами
        if let providedSession = session {
            self.session = providedSession
        } else {
            let config = URLSessionConfiguration.default
            
            // Разумные таймауты: не слишком долго ждать если сервер недоступен
            config.timeoutIntervalForRequest = 15.0   // 15 секунд для установки соединения
            config.timeoutIntervalForResource = 120.0 // 2 минуты для загрузки данных
            
            // Разрешаем использование мобильного интернета
            config.allowsCellularAccess = true
            
            // НЕ ждем появления соединения - сразу возвращаем ошибку если нет связи
            config.waitsForConnectivity = false
            
            self.session = URLSession(configuration: config)
            logger.info("✅ SyncRepository: URLSession настроен (таймауты: запрос=15с, ресурс=120с)")
        }
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
        
        guard var urlComponents = URLComponents(
            url: endpointURL,
            resolvingAgainstBaseURL: false
        ) else {
            logger.error("❌ Не удалось создать URLComponents для \(endpointURL.absoluteString)")
            return nil
        }
        
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
        logger.debug("⏱️ Таймаут запроса: 15с, таймаут ресурса: 120с")
        
        // Проверяем, является ли URL локальным IP адресом
        if isLocalIPAddress(url.absoluteString) {
            logger.warning("⚠️ Локальный IP адрес обнаружен: \(url.host ?? "неизвестно")")
            logger.warning("   💡 Локальный сервер может быть недоступен через мобильный интернет")
            logger.warning("   💡 Используйте Wi-Fi или настройте публичный сервер")
        }
        
        let startTime = Date()
        
        do {
            let (data, response) = try await session.data(from: url)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.debug("⏱️ Запрос выполнен за \(String(format: "%.2f", duration))с")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SyncError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                logger.error("❌ Ошибка сервера: \(httpResponse.statusCode)")
                throw SyncError.serverError(httpResponse.statusCode)
            }
            
            return (data, httpResponse)
        } catch let error as URLError {
            // Детальная обработка ошибок
            if error.code == .cancelled {
                logger.error("❌ Запрос отменен (cancelled)")
                logger.error("   URL: \(url.absoluteString)")
                
                if isLocalIPAddress(url.absoluteString) {
                    logger.error("   ⚠️ ЛОКАЛЬНЫЙ IP АДРЕС НЕДОСТУПЕН ЧЕРЕЗ МОБИЛЬНЫЙ ИНТЕРНЕТ!")
                    logger.error("   💡 Решение 1: Используйте Wi-Fi для доступа к локальному серверу")
                    logger.error("   💡 Решение 2: Настройте публичный сервер для мобильного интернета")
                    logger.error("   💡 Решение 3: Используйте VPN или туннель для доступа к локальному серверу")
                    throw SyncError.noInternet
                } else {
                    logger.error("   💡 Возможные причины:")
                    logger.error("      - Множественные одновременные запросы")
                    logger.error("      - Переключение между сетями во время запроса")
                    logger.error("      - Таймаут соединения")
                }
            }
            throw error
        }
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
            // Сервер недоступен (Connection refused)
            if urlError.code == .cannotConnectToHost {
                logger.warning("⚠️ Сервер недоступен (Connection refused)")
                return SyncError.serverUnavailable
            }
            
            // Таймаут соединения
            if urlError.code == .timedOut {
                logger.warning("⚠️ Таймаут соединения с сервером")
                return SyncError.serverUnavailable
            }
            
            // Проверка на отмену запроса (cancelled)
            if urlError.code == .cancelled {
                logger.error("❌ Запрос отменен (cancelled)")
                
                // Проверяем, является ли URL локальным IP
                if let url = urlError.failureURLString, isLocalIPAddress(url) {
                    logger.warning("   ⚠️ Локальный IP адрес недоступен")
                    return SyncError.serverUnavailable
                }
                
                return SyncError.networkError(urlError)
            }
            
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
    
    /// Проверяет, является ли URL локальным IP адресом
    /// - Parameter urlString: URL строка для проверки
    /// - Returns: true, если это локальный IP адрес
    private func isLocalIPAddress(_ urlString: String) -> Bool {
        // Проверяем паттерны локальных IP адресов
        let localIPPatterns = [
            "192.168.",
            "10.",
            "172.16.", "172.17.", "172.18.", "172.19.", "172.20.", "172.21.", "172.22.", "172.23.", "172.24.", "172.25.", "172.26.", "172.27.", "172.28.", "172.29.", "172.30.", "172.31.",
            "127.0.0.1",
            "localhost"
        ]
        
        return localIPPatterns.contains { urlString.contains($0) }
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
