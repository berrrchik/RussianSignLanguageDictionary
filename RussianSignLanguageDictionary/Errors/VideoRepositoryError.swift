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
    
    /// Видео не найдено в кеше (для избранных жестов в офлайн-режиме)
    case videoNotCached
    
    /// Нет подключения к интернету (для не избранных жестов)
    /// Краткосрочный кеш AVPlayer не сохраняется между запусками приложения,
    /// поэтому для просмотра видео не избранных жестов требуется интернет
    case noInternetConnection
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
        case (.supabaseError(let lhsMessage), .supabaseError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

