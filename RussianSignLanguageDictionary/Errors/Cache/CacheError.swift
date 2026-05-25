import Foundation

/// Ошибки кеширования данных (JSON)
/// Маппинг в ErrorMessageMapper
enum CacheError: Error {
    /// Не удалось получить доступ к директории документов
    case unableToAccessDocumentsDirectory

    /// Ошибка сохранения данных в кеш
    case unableToSave(Error)

    /// Ошибка загрузки данных из кеша
    case unableToLoad(Error)
}

// MARK: - UserFacingError

extension CacheError: UserFacingError {
    var userFacingMessage: String {
        switch self {
        case .unableToAccessDocumentsDirectory:
            return "Не удалось получить доступ к директории документов"
        case .unableToSave(let underlyingError):
            return "Ошибка сохранения кеша: \(underlyingError.localizedDescription)"
        case .unableToLoad(let underlyingError):
            return "Ошибка загрузки кеша: \(underlyingError.localizedDescription)"
        }
    }
}
