import Foundation
import os.log

/// Сервис для выполнения SBERT семантического поиска
final class SBERTSearchService {
    // MARK: - Properties
    
    private let baseURL: URL
    private let session: URLSession
    private let logger = Logger(subsystem: "com.rsl.SBERTSearchService", category: "search")
    
    // MARK: - Initialization
    
    /// Инициализатор сервиса
    /// - Parameters:
    ///   - baseURL: Базовый URL API (по умолчанию из APIConfig)
    ///   - session: URLSession для выполнения запросов (по умолчанию shared)
    init(
        baseURL: URL = APIConfig.baseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }
    
    // MARK: - Public Methods
    
    /// Выполняет SBERT семантический поиск жестов
    /// - Parameters:
    ///   - query: Текстовый запрос для поиска
    ///   - limit: Максимальное количество результатов (1-50, по умолчанию 10)
    ///   - minSimilarity: Минимальное значение сходства (0.0-1.0, по умолчанию 0.0)
    /// - Returns: Массив результатов поиска, отсортированных по сходству
    /// - Throws: SBERTSearchError при ошибках запроса
    func search(
        query: String,
        limit: Int = 10,
        minSimilarity: Double = 0.0
    ) async throws -> [SBERTSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw SBERTSearchError.serverError(
                code: "VALIDATION_ERROR",
                message: "Запрос не может быть пустым"
            )
        }
        
        // Валидация параметров
        let validatedLimit = max(1, min(50, limit))
        let validatedMinSimilarity = max(0.0, min(1.0, minSimilarity))
        
        // Построение URL (используем appendingPathComponent для надежности)
        let url = baseURL
            .appendingPathComponent("search")
            .appendingPathComponent("sbert")
        
        // Подготовка запроса
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180.0  // Увеличено для первой загрузки модели SBERT
        
        // Подготовка тела запроса
        let requestBody: [String: Any] = [
            "text": trimmedQuery,
            "limit": validatedLimit,
            "min_similarity": validatedMinSimilarity
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            logger.error("❌ Ошибка сериализации запроса: \(error.localizedDescription)")
            throw SBERTSearchError.invalidResponse
        }
        
        logger.info("🔍 SBERT поиск: '\(trimmedQuery, privacy: .public)' (limit: \(validatedLimit), minSimilarity: \(validatedMinSimilarity))")
        logger.info("🌐 URL: \(url.absoluteString)")
        
        // Выполнение запроса
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("❌ Неверный формат ответа")
                throw SBERTSearchError.invalidResponse
            }
            
            // Обработка HTTP статусов
            guard httpResponse.statusCode == 200 else {
                logger.warning("⚠️ HTTP ошибка: \(httpResponse.statusCode)")
                logger.warning("⚠️ URL: \(url.absoluteString)")
                
                // Попытка декодировать ошибку
                if let errorData = try? JSONDecoder().decode(SBERTSearchResponse.self, from: data),
                   let error = errorData.error {
                    logger.warning("⚠️ Ошибка сервера: \(error.code) - \(error.message)")
                    throw SBERTSearchError.serverError(code: error.code, message: error.message)
                }
                
                throw SBERTSearchError.httpError(statusCode: httpResponse.statusCode)
            }
            
            // Декодирование ответа
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(SBERTSearchResponse.self, from: data)
            
            guard searchResponse.success,
                  let searchData = searchResponse.data else {
                if let error = searchResponse.error {
                    throw SBERTSearchError.serverError(code: error.code, message: error.message)
                }
                logger.error("❌ Неизвестная ошибка в ответе")
                throw SBERTSearchError.unknown
            }
            
            logger.info("✅ Найдено результатов: \(searchData.totalFound)")
            return searchData.results
            
        } catch let error as SBERTSearchError {
            throw error
        } catch let urlError as URLError {
            logger.error("❌ Ошибка сети: \(urlError.localizedDescription)")
            logger.error("❌ Код ошибки: \(urlError.code.rawValue)")
            logger.error("❌ URL: \(url.absoluteString)")
            
            // Специальная обработка для ошибок подключения
            if urlError.code == .cannotConnectToHost || 
               urlError.code == .networkConnectionLost ||
               urlError.code == .timedOut {
                throw SBERTSearchError.httpError(statusCode: 0)  // Специальный код для сетевых ошибок
            }
            
            throw SBERTSearchError.httpError(statusCode: urlError.code.rawValue)
        } catch {
            logger.error("❌ Неизвестная ошибка: \(error.localizedDescription)")
            logger.error("❌ Тип ошибки: \(type(of: error))")
            throw SBERTSearchError.unknown
        }
    }
}
