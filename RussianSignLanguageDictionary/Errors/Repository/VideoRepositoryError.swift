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

// MARK: - Equatable

extension VideoRepositoryError: Equatable {
    static func == (lhs: VideoRepositoryError, rhs: VideoRepositoryError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL):
            return true
        case (.noInternetConnection, .noInternetConnection):
            return true
        case (.videoUnavailable, .videoUnavailable):
            return true
        default:
            return false
        }
    }
}
