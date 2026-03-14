import Foundation

/// Ошибки репозитория видео
/// Маппинг в ErrorMessageMapper
enum VideoRepositoryError: Error {
    /// URL видео недействителен или отсутствует
    case invalidURL
    
    /// Не удалось загрузить видео
    case downloadFailed
    
    /// Видео не найдено в кеше (для избранных жестов в офлайн-режиме)
    case videoNotCached
    
    /// Нет подключения к интернету (для не избранных жестов)
    /// Краткосрочный кеш AVPlayer не сохраняется между запусками приложения,
    /// поэтому для просмотра видео не избранных жестов требуется интернет
    case noInternetConnection
    
    // MARK: - Factory Methods
    
    /// Создаёт VideoRepositoryError из VideoCacheError
    /// - Parameter error: Ошибка кеширования видео
    /// - Returns: Соответствующий VideoRepositoryError
    static func from(_ error: VideoCacheError) -> VideoRepositoryError {
        switch error {
        case .invalidURL:
            return .invalidURL
        case .downloadFailed:
            return .downloadFailed
        case .fileNotFound:
            return .videoNotCached
        case .cacheDirectoryNotAvailable, .sessionNotConfigured:
            return .downloadFailed
        }
    }
}

// MARK: - Equatable

extension VideoRepositoryError: Equatable {
    static func == (lhs: VideoRepositoryError, rhs: VideoRepositoryError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL):
            return true
        case (.downloadFailed, .downloadFailed):
            return true
        case (.videoNotCached, .videoNotCached):
            return true
        case (.noInternetConnection, .noInternetConnection):
            return true
        default:
            return false
        }
    }
}
