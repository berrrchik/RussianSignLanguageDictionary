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
            return "Для первого запуска приложения необходимо подключение к интернету. После загрузки данных приложение будет работать офлайн."
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
        case .videoNotCached:
            return "Видео недоступно в офлайн-режиме. Добавьте жест в избранное для просмотра без интернета."
        case .noInternetConnection:
            return "Нет подключения к интернету. Для просмотра этого видео необходимо подключение к сети."
        }
    }
    
    // MARK: - SyncError Mapping
    
    static func message(for error: SyncError) -> String {
        switch error {
        case .noInternet:
            return "Нет подключения к интернету. Проверьте соединение и попробуйте снова."
        case .serverUnavailable:
            return "Сервер временно недоступен. Приложение работает на сохранённых данных."
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
    
    // MARK: - CacheError Mapping
    
    static func message(for error: CacheError) -> String {
        switch error {
        case .unableToAccessDocumentsDirectory:
            return "Не удалось получить доступ к директории документов"
        case .unableToSave(let underlyingError):
            return "Ошибка сохранения кеша: \(underlyingError.localizedDescription)"
        case .unableToLoad(let underlyingError):
            return "Ошибка загрузки кеша: \(underlyingError.localizedDescription)"
        }
    }
    
    // MARK: - VideoCacheError Mapping
    
    static func message(for error: VideoCacheError) -> String {
        switch error {
        case .invalidURL:
            return "Невалидный URL видео"
        case .cacheDirectoryNotAvailable:
            return "Директория кеша недоступна"
        case .sessionNotConfigured:
            return "Внутренняя ошибка: сессия загрузки не настроена"
        case .downloadFailed:
            return "Не удалось загрузить видео"
        case .fileNotFound:
            return "Файл видео не найден в кеше"
        }
    }
    
    // MARK: - SBERTSearchError Mapping
    
    static func message(for error: SBERTSearchError) -> String {
        switch error {
        case .invalidResponse:
            return "Неверный формат ответа от сервера поиска"
        case .httpError(let statusCode):
            return "Ошибка сети: \(statusCode). Попробуйте позже."
        case .serverError(let code, let message):
            if code == "VALIDATION_ERROR" {
                return "Ошибка запроса: \(message)"
            } else if code == "SEARCH_ERROR" {
                return "Семантический поиск временно недоступен. Используется текстовый поиск."
            }
            return "Ошибка поиска: \(message)"
        case .unknown:
            return "Неизвестная ошибка при поиске"
        }
    }
    
    static func message(for error: LessonRepositoryError) -> String {
        switch error {
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
        
        if let cacheError = error as? CacheError {
            return message(for: cacheError)
        }
        
        if let videoCacheError = error as? VideoCacheError {
            return message(for: videoCacheError)
        }
        
        if let sbertError = error as? SBERTSearchError {
            return message(for: sbertError)
        }
        
        if let lessonError = error as? LessonRepositoryError {
            return message(for: lessonError)
        }
        
        return "Произошла ошибка: \(error.localizedDescription)"
    }
}

