import Foundation

/// Ошибки кеширования видео (файлы)
/// Маппинг в ErrorMessageMapper
enum VideoCacheError: Error {
    /// Невалидный URL видео
    case invalidURL

    /// Нет подключения к интернету
    case noInternetConnection
    
    /// Директория кеша недоступна
    case cacheDirectoryNotAvailable
    
    /// URLSession не настроен
    case sessionNotConfigured
    
    /// Видео временно недоступно
    case videoUnavailable
    
    /// Файл видео не найден в кеше
    case fileNotFound
}

// MARK: - UserFacingError

extension VideoCacheError: UserFacingError {
    var userFacingMessage: String {
        switch self {
        case .invalidURL:
            return "Невалидный URL видео"
        case .noInternetConnection:
            return "Нет интернета."
        case .cacheDirectoryNotAvailable:
            return "Директория кеша недоступна"
        case .sessionNotConfigured:
            return "Внутренняя ошибка: сессия загрузки не настроена"
        case .videoUnavailable:
            return "Видео сейчас недоступно."
        case .fileNotFound:
            return "Файл видео не найден в кеше"
        }
    }
}
