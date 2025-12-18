import Foundation

/// Ошибки кеширования видео (файлы)
/// Маппинг в ErrorMessageMapper
enum VideoCacheError: Error {
    /// Невалидный URL видео
    case invalidURL
    
    /// Директория кеша недоступна
    case cacheDirectoryNotAvailable
    
    /// URLSession не настроен
    case sessionNotConfigured
    
    /// Ошибка загрузки видео
    case downloadFailed
    
    /// Файл видео не найден в кеше
    case fileNotFound
}
