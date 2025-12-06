import Foundation

/// Маппер для конвертации ошибок в  сообщения
/// Error enum определяют только случаи ошибок, этот маппер отвечает за сообщения.
enum ErrorMessageMapper {
    
    // MARK: - SignRepositoryError Mapping
    
    static func message(for error: SignRepositoryError) -> String {
        switch error {
        case .fileNotFound:
            return "Не удалось загрузить данные"
        case .unableToReadFile:
            return "Ошибка чтения файла"
        case .decodingError(let underlyingError):
            return "Ошибка обработки данных: \(underlyingError.localizedDescription)"
        case .invalidDataFormat:
            return "Неверный формат данных"
        case .noDataAvailable:
            return "Данные недоступны. Проверьте подключение к интернету."
        }
    }
    
    // MARK: - VideoRepositoryError Mapping

    static func message(for error: VideoRepositoryError) -> String {
        switch error {
        case .invalidURL:
            return "Неверный URL видео"
        case .downloadFailed:
            return "Не удалось загрузить видео"
        case .supabaseError(let message):
            return "Ошибка сервера: \(message)"
        }
    }
    
    // MARK: - SyncError Mapping
    
    static func message(for error: SyncError) -> String {
        switch error {
        case .noInternet:
            return "Нет подключения к интернету. Проверьте соединение и попробуйте снова."
        case .serverError(let code):
            return "Ошибка сервера: \(code). Попробуйте позже."
        case .networkError(let underlyingError):
            return "Ошибка сети: \(underlyingError.localizedDescription)"
        case .decodingError(let underlyingError):
            return "Ошибка обработки данных: \(underlyingError.localizedDescription)"
        case .invalidResponse:
            return "Неверный ответ сервера. Попробуйте позже."
        }
    }
    
    // MARK: - Generic Error Mapping
    
    static func message(for error: Error) -> String {
        if let signError = error as? SignRepositoryError {
            return message(for: signError)
        }
        
        if let videoError = error as? VideoRepositoryError {
            return message(for: videoError)
        }
        
        if let syncError = error as? SyncError {
            return message(for: syncError)
        }
        
        return "Произошла ошибка: \(error.localizedDescription)"
    }
}

