import Foundation

/// Ошибки синхронизации данных
/// Маппинг сообщений в ErrorMessageMapper
enum SyncError: Error {
    /// Нет подключения к интернету
    case noInternet

    /// Сервер недоступен (Connection refused, timeout)
    case serverUnavailable

    /// Ошибка сервера с кодом статуса
    case serverError(Int)

    /// Ошибка сети
    case networkError(Error)

    /// Ошибка декодирования данных
    case decodingError(Error)

    /// Неверный ответ сервера
    case invalidResponse
}

// MARK: - UserFacingError

extension SyncError: UserFacingError {
    var userFacingMessage: String {
        switch self {
        case .noInternet:
            return "Нет подключения к интернету. Проверьте соединение и попробуйте снова."
        case .serverUnavailable:
            return "Сервер временно недоступен. Приложение работает на сохранённых данных."
        case .serverError(let code):
            return "Ошибка сервера: \(code). Попробуйте позже."
        case .networkError(let underlyingError):
            return "Ошибка сети: \(underlyingError.localizedDescription)"
        case .decodingError(let underlyingError):
            return "Ошибка обработки данных: \(underlyingError.localizedDescription)"
        case .invalidResponse:
            return "Неверный ответ сервера. Попробуйте позже."
        }
    }
}

// MARK: - Factory Methods

extension SyncError {
    /// Создаёт SyncError из URLError
    /// - Parameter error: Сетевая ошибка
    /// - Returns: Соответствующий SyncError
    static func from(_ error: Error) -> SyncError {
        guard let urlError = error as? URLError else {
            return .networkError(error)
        }

        switch urlError.code {
        case .cannotConnectToHost, .timedOut:
            return .serverUnavailable

        case .notConnectedToInternet, .networkConnectionLost:
            return .noInternet

        case .cancelled:
            if let url = urlError.failureURLString, NetworkAddressValidator.isLocalAddress(url) {
                return .serverUnavailable
            }
            return .networkError(urlError)

        default:
            return .networkError(urlError)
        }
    }
}
