import Foundation

/// Протокол репозитория для работы с видео из Supabase Storage
protocol VideoRepositoryProtocol {
    /// Получает URL видео для указанного жеста
    /// - Parameter sign: Модель жеста
    /// - Returns: URL видео файла
    /// - Throws: VideoRepositoryError в случае ошибки
    func getVideoURL(for sign: Sign) async throws -> URL
    
    /// Предзагружает видео в кэш для указанного жеста
    /// - Parameter sign: Модель жеста
    /// - Throws: VideoRepositoryError в случае ошибки
    func preloadVideo(for sign: Sign) async throws
    
    /// Очищает кэш видео URL
    func clearCache()
}

