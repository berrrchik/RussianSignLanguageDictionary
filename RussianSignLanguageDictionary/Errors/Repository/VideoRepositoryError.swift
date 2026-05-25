import Foundation

/// Ошибки репозитория видео
/// Маппинг в ErrorMessageMapper
enum VideoRepositoryError: Error {
    /// URL видео недействителен или отсутствует
    case invalidURL
    
    /// Нет подключения к интернету (для не избранных жестов)
    /// Краткосрочный кеш AVPlayer не сохраняется между запусками приложения,
    /// поэтому для просмотра видео не избранных жестов требуется интернет
    case noInternetConnection

    /// Видео или сервер временно недоступны
    case videoUnavailable
    
    // MARK: - Factory Methods
    
    /// Создаёт VideoRepositoryError из VideoCacheError
    /// - Parameter error: Ошибка кеширования видео
    /// - Returns: Соответствующий VideoRepositoryError
    static func from(_ error: VideoCacheError) -> VideoRepositoryError {
        switch error {
        case .invalidURL:
            return .invalidURL
        case .noInternetConnection, .fileNotFound:
            return .noInternetConnection
        case .videoUnavailable:
            return .videoUnavailable
        case .cacheDirectoryNotAvailable, .sessionNotConfigured:
            return .videoUnavailable
        }
    }
}

// MARK: - UserFacingError

extension VideoRepositoryError: UserFacingError {
    var userFacingMessage: String {
        switch self {
        case .invalidURL:
            return "Неверный адрес видео."
        case .noInternetConnection:
            return "Нет интернета."
        case .videoUnavailable:
            return "Видео сейчас недоступно."
        }
    }
}
