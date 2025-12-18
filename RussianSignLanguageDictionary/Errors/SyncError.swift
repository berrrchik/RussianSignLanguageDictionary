import Foundation

/// Ошибки синхронизации данных
/// Маппинг в ErrorMessageMapper
enum SyncError: Error {
    /// Нет подключения к интернету
    case noInternet
    
    /// Сервер недоступен (Connection refused, timeout)
    case serverUnavailable
    
    /// Ошибка сервера с кодом статуса
    case serverError(Int)
    
    /// Ошибка сети
    case networkError(Error)
    
    /// Ошибка декодирования данных
    case decodingError(Error)
    
    /// Неверный ответ сервера
    case invalidResponse
}
