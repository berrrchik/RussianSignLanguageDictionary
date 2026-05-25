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

// MARK: - UserFacingError

extension LessonRepositoryError: UserFacingError {
    var userFacingMessage: String {
        switch self {
        case .noDataAvailable:
            return "Данные уроков недоступны. Попробуйте сначала выполнить синхронизацию."
        case .invalidURL:
            return "Неверный адрес видео урока"
        case .noInternetConnection:
            return "Нет подключения к интернету. Видео уроков доступно только при наличии интернета."
        case .downloadFailed:
            return "Не удалось загрузить видео урока. Попробуйте позже."
        }
    }
}
