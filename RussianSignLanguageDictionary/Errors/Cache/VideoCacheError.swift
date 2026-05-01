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

extension VideoCacheError: Equatable {
    static func == (lhs: VideoCacheError, rhs: VideoCacheError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.noInternetConnection, .noInternetConnection),
             (.cacheDirectoryNotAvailable, .cacheDirectoryNotAvailable),
             (.sessionNotConfigured, .sessionNotConfigured),
             (.videoUnavailable, .videoUnavailable),
             (.fileNotFound, .fileNotFound):
            return true
        default:
            return false
        }
    }
}
