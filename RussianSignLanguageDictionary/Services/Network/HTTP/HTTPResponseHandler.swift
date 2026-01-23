import Foundation

/// Результат обработки HTTP-ответа
enum HTTPResponseResult {
    /// Успешный ответ с данными
    case success(Data)
    /// 304 Not Modified — данные не изменились
    case notModified
    /// Ошибка при обработке ответа
    case error(SyncError)
}

/// Обработчик HTTP-ответов
/// Извлекает логику обработки статус-кодов из SyncRepository
struct HTTPResponseHandler {
    // MARK: - Public Methods
    
    /// Обрабатывает HTTP-ответ и возвращает результат
    /// - Parameters:
    ///   - response: URLResponse от сервера
    ///   - data: Полученные данные
    /// - Returns: Результат обработки
    func handle(response: URLResponse, data: Data) -> HTTPResponseResult {
        guard let httpResponse = response as? HTTPURLResponse else {
            return .error(.invalidResponse)
        }
        
        switch httpResponse.statusCode {
        case 200:
            return .success(data)
        case 304:
            return .notModified
        default:
            return .error(.serverError(httpResponse.statusCode))
        }
    }
    
    /// Извлекает ETag из HTTP-ответа
    /// - Parameter response: URLResponse от сервера
    /// - Returns: Значение ETag или nil
    func extractETag(from response: URLResponse) -> String? {
        (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")
    }
}
