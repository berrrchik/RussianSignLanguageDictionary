import Foundation

/// Ошибки репозитория уроков
enum LessonRepositoryError: Error, LocalizedError {
    /// Данные уроков недоступны (не загружены или кеш пуст)
    case noDataAvailable
    
    /// Невалидный URL видео урока
    case invalidURL
    
    /// Нет подключения к интернету для загрузки видео
    case noInternetConnection
    
    /// Ошибка загрузки видео
    case downloadFailed
}
