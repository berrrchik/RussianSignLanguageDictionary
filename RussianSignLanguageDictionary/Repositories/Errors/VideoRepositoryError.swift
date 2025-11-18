import Foundation

/// Ошибки репозитория видео
/// Маппинг в ErrorMessageMapper
enum VideoRepositoryError: Error {
    /// URL видео недействителен или отсутствует
    case invalidURL
    
    /// Ошибка при работе с Supabase Storage
    case supabaseError(String)
    
    /// Не удалось загрузить видео
    case downloadFailed
}

