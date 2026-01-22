import Foundation

/// Протокол репозитория для работы с видео из Supabase Storage
///
/// Поддерживает двухуровневое кеширование:
/// - **Долгосрочный кеш (useFavoritesCache: true)**: URLCache на диске для избранных жестов
/// - **Краткосрочный кеш (useFavoritesCache: false)**: AVPlayer кеширует в памяти автоматически
///
/// ⚠️ **Важно**: Краткосрочный кеш AVPlayer хранится только в оперативной памяти
/// и не сохраняется между запусками приложения.
protocol VideoRepositoryProtocol {
    /// Получает URL видео для указанного жеста (для обратной совместимости)
    /// - Parameter sign: Модель жеста
    /// - Returns: URL видео файла
    /// - Throws: VideoRepositoryError в случае ошибки
    func getVideoURL(for sign: Sign) async throws -> URL
    
    func getVideoURL(for lesson: Lesson) async throws -> URL
    
    /// Получает URL видео для указанного видео объекта
    /// - Parameters:
    ///   - video: Модель видео
    ///   - useFavoritesCache: Использовать долгосрочный кеш для избранного (по умолчанию false)
    /// - Returns: URL видео файла
    /// - Throws: VideoRepositoryError в случае ошибки
    ///
    /// При `useFavoritesCache: true`:
    /// - Использует URLCache с cachePolicy `.returnCacheDataElseLoad`
    /// - Видео сохраняется на диске и доступно офлайн
    ///
    /// При `useFavoritesCache: false`:
    /// - Использует стандартное кеширование AVPlayer (в памяти)
    /// - Требуется интернет-соединение после перезапуска приложения
    func getVideoURL(for video: SignVideo, useFavoritesCache: Bool) async throws -> URL
    
    /// Предзагружает видео в кэш для указанного жеста
    /// - Parameter sign: Модель жеста
    /// - Throws: VideoRepositoryError в случае ошибки
    func preloadVideo(for sign: Sign) async throws
    
    /// Предзагружает видео в долгосрочный кеш избранного
    /// - Parameters:
    ///   - video: Видео для предзагрузки
    ///   - useFavoritesCache: Использовать долгосрочный кеш (по умолчанию true)
    /// - Throws: VideoRepositoryError в случае ошибки
    func preloadVideo(video: SignVideo, useFavoritesCache: Bool) async throws
    
    /// Очищает кэш видео URL
    func clearCache()
}

