import Foundation

/// Ошибки репозитория видео
enum VideoRepositoryError: LocalizedError {
    /// URL видео недействителен
    case invalidURL
    
    /// Не удалось получить URL из Supabase Storage
    case unableToFetchURL
    
    /// Ошибка при работе с Supabase
    case supabaseError(Error)
    
    /// Видео файл не найден в Storage
    case videoNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Недействительный URL видео"
        case .unableToFetchURL:
            return "Не удалось получить URL видео из Supabase Storage"
        case .supabaseError(let error):
            return "Ошибка Supabase: \(error.localizedDescription)"
        case .videoNotFound:
            return "Видео файл не найден в хранилище"
        }
    }
}

