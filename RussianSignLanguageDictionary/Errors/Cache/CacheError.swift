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
