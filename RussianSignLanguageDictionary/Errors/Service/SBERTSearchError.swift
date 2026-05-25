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
        userFacingMessage
    }
}

// MARK: - UserFacingError

extension SBERTSearchError: UserFacingError {
    var userFacingMessage: String {
        switch self {
        case .invalidResponse:
            return "Неверный формат ответа от сервера поиска"
        case .httpError(let statusCode):
            return "Ошибка сети: \(statusCode). Попробуйте позже."
        case .serverError(let code, let message):
            if code == "VALIDATION_ERROR" {
                return "Ошибка запроса: \(message)"
            } else if code == "SEARCH_ERROR" {
                return "Семантический поиск временно недоступен. Используется текстовый поиск."
            }
            return "Ошибка поиска: \(message)"
        case .unknown:
            return "Неизвестная ошибка при поиске"
        }
    }
}
