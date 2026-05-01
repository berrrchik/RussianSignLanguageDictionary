import Foundation

/// Протокол для сервиса кеширования видео
///
/// Обеспечивает абстракцию для работы с файловым кешем видео,
/// что позволяет легко тестировать зависимые компоненты.
protocol VideoCacheServiceProtocol {
    // MARK: - Cache Checking
    
    /// Проверяет наличие видео в кеше
    /// - Parameter video: Видео для проверки
    /// - Returns: true если видео есть в кеше
    func isVideoCached(_ video: SignVideo) -> Bool
    
    /// Проверяет наличие видео в кеше по URL
    /// - Parameter url: URL видео
    /// - Returns: true если видео есть в кеше
    func isVideoCached(url: URL) -> Bool
    
    // MARK: - Cache Access
    
    /// Возвращает URL кешированного видео файла
    /// - Parameter video: Видео
    /// - Returns: URL файла или nil если не кеширован
    func getCachedVideoURL(_ video: SignVideo) -> URL?
    
    /// Возвращает URL кешированного видео файла по оригинальному URL
    /// - Parameter originalURL: Оригинальный URL видео
    /// - Returns: URL файла или nil если не кеширован
    func getCachedVideoURL(originalURL: URL) -> URL?
    
    // MARK: - Download & Cache
    
    /// Загружает видео и сохраняет в кеш
    /// - Parameter video: Видео для загрузки
    /// - Returns: URL локального файла
    /// - Throws: Ошибка при загрузке
    func downloadAndCache(video: SignVideo) async throws -> URL
    
    /// Загружает видео по URL и сохраняет в кеш
    /// - Parameter url: URL видео
    /// - Returns: URL локального файла
    /// - Throws: Ошибка при загрузке
    func downloadAndCache(url: URL) async throws -> URL

    /// Продвигает уже скачанный локальный файл в долгосрочный кеш избранного
    /// - Parameters:
    ///   - video: Видео, для которого нужно создать durable-копию
    ///   - localFileURL: Уже существующий локальный файл
    /// - Returns: URL файла в директории избранного
    func promoteCachedVideo(_ video: SignVideo, from localFileURL: URL) throws -> URL
    
    /// Предзагружает видео в кеш (асинхронно, без ожидания)
    /// - Parameter video: Видео для предзагрузки
    func preloadVideo(_ video: SignVideo) async
    
    /// Предзагружает все видео жеста
    /// - Parameter videos: Массив видео
    func preloadVideos(_ videos: [SignVideo]) async
    
    // MARK: - Cache Clearing
    
    /// Очищает кеш для конкретного видео
    /// - Parameter video: Видео для удаления из кеша
    func clearCache(for video: SignVideo)
    
    /// Очищает кеш по URL видео
    /// - Parameter url: URL видео
    func clearCache(for url: URL)
    
    /// Очищает кеш для всех видео жеста
    /// - Parameters:
    ///   - signId: ID жеста (для логирования)
    ///   - videos: Массив видео
    func clearCache(for signId: String, videos: [SignVideo])
    
    /// Полностью очищает весь кеш видео
    func clearAllCache()
    
    // MARK: - Cache Size Management
    
    /// Возвращает текущий размер кеша на диске в байтах
    /// - Returns: Размер в байтах
    func getCacheSize() -> Int
    
    /// Проверяет и поддерживает лимит размера кеша
    func ensureCacheLimit()
}
