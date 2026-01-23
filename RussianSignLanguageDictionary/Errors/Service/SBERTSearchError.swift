import Foundation

/// Ошибки SBERT поиска
enum SBERTSearchError: LocalizedError {
    /// Неверный формат ответа
    case invalidResponse
    
    /// HTTP ошибка с кодом статуса
    case httpError(statusCode: Int)
    
    /// Ошибка сервера с кодом и сообщением
    case serverError(code: String, message: String)
    
    /// Неизвестная ошибка
    case unknown
    
    var errorDescription: String? {
        return ErrorMessageMapper.message(for: self)
    }
}
