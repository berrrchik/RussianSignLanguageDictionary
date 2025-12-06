import Foundation

/// Ошибки синхронизации данных
/// Маппинг в ErrorMessageMapper
enum SyncError: Error {
    /// Нет подключения к интернету
    case noInternet
    
    /// Ошибка сервера с кодом статуса
    case serverError(Int)
    
    /// Ошибка сети
    case networkError(Error)
    
    /// Ошибка декодирования данных
    case decodingError(Error)
    
    /// Неверный ответ сервера
    case invalidResponse
}
