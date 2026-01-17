import Foundation
import os.log

/// Репозиторий для синхронизации данных с сервером
/// Использует Raw API endpoints для получения данных
final class SyncRepository: SyncRepositoryProtocol {
    // MARK: - Properties
    
    private let baseURL: URL
    private let session: URLSession
    private let etagManager: ETagManager
    private let cacheService: CacheService
    private let logger = Logger(subsystem: "com.rsl.SyncRepository", category: "sync")
    
    // MARK: - Initialization
    
    init(
        baseURL: URL = APIConfig.baseURL,
        session: URLSession? = nil,
        cacheService: CacheService = CacheService(),
        etagManager: ETagManager = ETagManager()
    ) {
        self.baseURL = baseURL
        self.cacheService = cacheService
        self.etagManager = etagManager
        self.session = session ?? Self.createDefaultSession()
    }
    
    // MARK: - SyncRepositoryProtocol
    
    func checkForUpdates(lastUpdated: Date?) async throws -> SyncMetadata {
        guard let url = buildCheckUpdatesURL(lastUpdated: lastUpdated) else {
            throw SyncError.invalidResponse
        }
        
        let cachedETag = etagManager.getETag(for: .syncCheck)
        let request = buildRequest(url: url, etag: cachedETag)
        logETagStatus(cachedETag: cachedETag, endpoint: "/sync/check")
        
        return try await performRequest(
            request: request,
            etagKey: .syncCheck,
            notModifiedHandler: {
                SyncMetadata(lastUpdated: lastUpdated ?? Date(), hasUpdates: false)
            }
        )
    }
    
    func fetchAllData(
        cachedDataProvider: @escaping () throws -> SyncData
    ) async throws -> SyncData {
        let url = buildFetchDataURL()
        let cachedETag = etagManager.getETag(for: .syncData)
        let request = buildRequest(url: url, etag: cachedETag)
        logETagStatus(cachedETag: cachedETag, endpoint: "/sync/data")
        
        return try await performRequest(
            request: request,
            etagKey: .syncData,
            notModifiedHandler: { [logger] in
                logger.info("📦 304: Используем кеш памяти")
                return try cachedDataProvider()
            }
        )
    }
    
    // MARK: - Generic Request Handler
    
    private func performRequest<T: Decodable>(
        request: URLRequest,
        etagKey: ETagManager.StorageKey,
        notModifiedHandler: () throws -> T
    ) async throws -> T {
        var responseData: Data?
        
        do {
            let (data, response) = try await executeNetworkRequest(request: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SyncError.invalidResponse
            }
            
            if httpResponse.statusCode == 304 {
                logger.info("✅ ETag match: 304 Not Modified для \(request.url?.path ?? "")")
                return try notModifiedHandler()
            }
            
            guard httpResponse.statusCode == 200 else {
                logger.error("❌ Ошибка сервера: \(httpResponse.statusCode)")
                throw SyncError.serverError(httpResponse.statusCode)
            }
            
            responseData = data
            
            processResponseETag(response: httpResponse, request: request, key: etagKey)
            
            logResponsePreview(data: data, endpoint: request.url?.path ?? "")
            
            return try createDecoder().decode(T.self, from: data)
            
        } catch let error as DecodingError {
            logDecodingError(error, data: responseData ?? Data())
            throw SyncError.decodingError(error)
        } catch let error as SyncError {
            throw error
        } catch {
            throw handleNetworkError(error)
        }
    }
    
    // MARK: - Network Execution
    
    private func executeNetworkRequest(request: URLRequest) async throws -> (Data, URLResponse) {
        let urlString = request.url?.absoluteString ?? "unknown"
        logger.info("🔄 Запрос: \(urlString, privacy: .public)")
        
        warnIfLocalAddress(urlString)
        
        let startTime = Date()
        
        do {
            let result = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            logger.debug("⏱️ Запрос выполнен за \(String(format: "%.2f", duration))с")
            return result
        } catch let error as URLError where error.code == .cancelled {
            handleCancelledRequest(urlString: urlString)
            throw error
        }
    }
    
    // MARK: - Error Handling
    
    private func handleNetworkError(_ error: Error) -> SyncError {
        guard let urlError = error as? URLError else {
            logger.error("❌ Неизвестная ошибка: \(error.localizedDescription)")
            return .networkError(error)
        }
        
        switch urlError.code {
        case .cannotConnectToHost, .timedOut:
            logger.warning("⚠️ Сервер недоступен: \(urlError.code.rawValue)")
            return .serverUnavailable
            
        case .cancelled:
            return handleCancelledError(urlError)
            
        case .notConnectedToInternet, .networkConnectionLost:
            logger.warning("⚠️ Нет подключения к интернету")
            return .noInternet
            
        default:
            logger.error("❌ Ошибка сети: \(urlError.localizedDescription)")
            return .networkError(urlError)
        }
    }
    
    private func handleCancelledError(_ error: URLError) -> SyncError {
        logger.error("❌ Запрос отменён")
        
        if let url = error.failureURLString, NetworkAddressValidator.isLocalAddress(url) {
            logger.warning("⚠️ Локальный IP недоступен")
            return .serverUnavailable
        }
        
        return .networkError(error)
    }
    
    // MARK: - ETag Processing
    
    private func processResponseETag(
        response: HTTPURLResponse,
        request: URLRequest,
        key: ETagManager.StorageKey
    ) {
        guard let newETagRaw = response.value(forHTTPHeaderField: "ETag") else {
            logger.debug("⚠️ ETag отсутствует в ответе")
            return
        }
        
        let newETag = etagManager.normalizeETag(newETagRaw)
        logETagComparison(request: request, newETag: newETag, newETagRaw: newETagRaw)
        etagManager.saveETag(newETagRaw, for: key)
    }
    
    private func logETagComparison(request: URLRequest, newETag: String, newETagRaw: String) {
        guard let sentETagRaw = request.value(forHTTPHeaderField: "If-None-Match") else {
            logger.debug("🔄 Новый ETag получен: \(newETag) (len=\(newETag.count))")
            return
        }
        
        let sentETag = etagManager.normalizeETag(sentETagRaw)
        
        if sentETag == newETag {
            logger.debug("⚠️ ETag совпадает, но сервер вернул 200 OK")
        } else {
            logger.debug("🔄 ETag изменился: \(sentETag) → \(newETag)")
        }
    }
    
    // MARK: - Logging Helpers
    
    private func logETagStatus(cachedETag: String?, endpoint: String) {
        if let etag = cachedETag {
            logger.debug("🔄 Отправка If-None-Match для \(endpoint): \(etag)")
        } else {
            logger.debug("🔄 ETag для \(endpoint): первый запрос")
        }
    }
    
    private func logResponsePreview(data: Data, endpoint: String) {
        guard let preview = String(data: data, encoding: .utf8)?.prefix(200) else { return }
        logger.debug("📥 Ответ \(endpoint): \(preview, privacy: .public)...")
    }
    
    private func warnIfLocalAddress(_ urlString: String) {
        guard NetworkAddressValidator.isLocalAddress(urlString) else { return }
        
        logger.warning("⚠️ Локальный IP адрес обнаружен")
        logger.warning("   💡 Может быть недоступен через мобильный интернет")
    }
    
    private func handleCancelledRequest(urlString: String) {
        logger.error("❌ Запрос отменён")
        
        if NetworkAddressValidator.isLocalAddress(urlString) {
            logger.error("   ⚠️ ЛОКАЛЬНЫЙ IP НЕДОСТУПЕН!")
            logger.error("   💡 Используйте Wi-Fi или настройте публичный сервер")
        }
    }
    
    // MARK: - Decoder
    
    private func createDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
    
    private func logDecodingError(_ error: DecodingError, data: Data) {
        logger.error("❌ Ошибка декодирования: \(error.localizedDescription)")
        
        switch error {
        case .keyNotFound(let key, let context):
            logger.error("   Отсутствует ключ: \(key.stringValue)")
            logger.error("   Путь: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            
        case .dataCorrupted(let context):
            logger.error("   Проблема с данными: \(context.debugDescription)")
            
        case .typeMismatch(let type, let context):
            logger.error("   Несоответствие типа: ожидался \(type)")
            logger.error("   Путь: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            
        case .valueNotFound(let type, let context):
            logger.error("   Значение не найдено: \(type)")
            logger.error("   Путь: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            
        @unknown default:
            break
        }
        
        logResponseKeys(data: data)
    }
    
    private func logResponseKeys(data: Data) {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        logger.debug("   Ключи в ответе: \(dict.keys.joined(separator: ", "))")
    }
    
    // MARK: - URL Building
    
    private func buildCheckUpdatesURL(lastUpdated: Date?) -> URL? {
        let endpointURL = baseURL
            .appendingPathComponent("sync")
            .appendingPathComponent("check")
            .appendingPathComponent("raw")
        
        guard var urlComponents = URLComponents(
            url: endpointURL,
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }
        
        if let lastUpdated = lastUpdated {
            let timestamp = Int(lastUpdated.timeIntervalSince1970)
            urlComponents.queryItems = [
                URLQueryItem(name: "last_updated", value: String(timestamp))
            ]
        }
        
        return urlComponents.url
    }
    
    private func buildFetchDataURL() -> URL {
        baseURL
            .appendingPathComponent("sync")
            .appendingPathComponent("data")
            .appendingPathComponent("raw")
    }
    
    private func buildRequest(url: URL, etag: String?) -> URLRequest {
        var request = URLRequest(url: url)
        
        if let etag = etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        return request
    }
    
    // MARK: - Session Configuration
    
    private static func createDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 120.0
        config.allowsCellularAccess = true
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }
}
