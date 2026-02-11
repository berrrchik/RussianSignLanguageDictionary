import Foundation
import os.log

/// Сервис для управления кешем видео
/// 
/// Обеспечивает двухуровневое кеширование:
/// - **Долгосрочный кеш (файлы на диске)**: для избранных жестов, сохраняется до 500MB
/// - **Краткосрочный кеш (AVPlayer)**: для обычного просмотра, только в памяти
///
/// ⚠️ **Важно**: Краткосрочный кеш AVPlayer хранится только в оперативной памяти
/// и не сохраняется между запусками приложения. После перезапуска приложения
/// для просмотра видео не избранных жестов требуется активное интернет-соединение.
///
/// ## Архитектура
/// Сервис использует композицию для разделения ответственностей:
/// - `VideoCacheDirectoryManager` — работа с файловой системой
/// - `VideoCacheDownloader` — загрузка видео с сервера
final class VideoCacheService: VideoCacheServiceProtocol {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.videoCache", category: "VideoCacheService")
    
    /// Менеджер директории кеша
    private let directoryManager: VideoCacheDirectoryManager
    
    /// Загрузчик видео
    private let downloader: VideoCacheDownloader
    
    // MARK: - Initialization
    
    /// Инициализатор для Dependency Injection
    /// - Parameters:
    ///   - directoryManager: Менеджер директории (опционально, создаётся по умолчанию)
    ///   - downloader: Загрузчик видео (опционально, создаётся по умолчанию)
    init(
        directoryManager: VideoCacheDirectoryManager? = nil,
        downloader: VideoCacheDownloader? = nil
    ) {
        let manager = directoryManager ?? VideoCacheDirectoryManager()
        self.directoryManager = manager
        self.downloader = downloader ?? VideoCacheDownloader(directoryManager: manager)
        logger.info("✅ VideoCacheService инициализирован")
    }
    
    // MARK: - Cache Checking
    
    /// Проверяет наличие видео в кеше
    /// - Parameter video: Видео для проверки
    /// - Returns: true если видео есть в кеше
    func isVideoCached(_ video: SignVideo) -> Bool {
        guard let url = URL(string: video.url) else { return false }
        return isVideoCached(url: url)
    }
    
    /// Проверяет наличие видео в кеше по URL
    /// - Parameter url: URL видео
    /// - Returns: true если видео есть в кеше
    func isVideoCached(url: URL) -> Bool {
        let id = directoryManager.videoId(from: url)
        guard let fileURL = directoryManager.cacheFileURL(for: id) else { return false }
        return directoryManager.fileExists(at: fileURL)
    }
    
    // MARK: - Cache Access
    
    /// Возвращает URL кешированного видео файла
    /// - Parameter video: Видео
    /// - Returns: URL файла или nil если не кеширован
    func getCachedVideoURL(_ video: SignVideo) -> URL? {
        guard let url = URL(string: video.url) else { return nil }
        return getCachedVideoURL(originalURL: url)
    }
    
    /// Возвращает URL кешированного видео файла по оригинальному URL
    /// - Parameter originalURL: Оригинальный URL видео
    /// - Returns: URL файла или nil если не кеширован
    func getCachedVideoURL(originalURL: URL) -> URL? {
        return downloader.getCachedVideoURL(originalURL: originalURL)
    }
    
    // MARK: - Download & Cache
    
    /// Загружает видео и сохраняет в кеш
    /// - Parameter video: Видео для загрузки
    /// - Returns: URL локального файла
    /// - Throws: Ошибка при загрузке
    func downloadAndCache(video: SignVideo) async throws -> URL {
        return try await downloader.downloadAndCache(video: video)
    }
    
    /// Загружает видео по URL и сохраняет в кеш
    /// - Parameter url: URL видео
    /// - Returns: URL локального файла
    /// - Throws: Ошибка при загрузке
    func downloadAndCache(url: URL) async throws -> URL {
        return try await downloader.downloadAndCache(url: url)
    }
    
    /// Предзагружает видео в кеш (асинхронно, без ожидания)
    /// - Parameter video: Видео для предзагрузки
    func preloadVideo(_ video: SignVideo) async {
        await downloader.preloadVideo(video)
    }
    
    /// Предзагружает все видео жеста
    /// - Parameter videos: Массив видео
    func preloadVideos(_ videos: [SignVideo]) async {
        await downloader.preloadVideos(videos)
    }
    
    // MARK: - Cache Clearing
    
    /// Очищает кеш для конкретного видео
    /// - Parameter video: Видео для удаления из кеша
    func clearCache(for video: SignVideo) {
        guard let url = URL(string: video.url) else { return }
        clearCache(for: url)
    }
    
    /// Очищает кеш по URL видео
    /// - Parameter url: URL видео
    func clearCache(for url: URL) {
        directoryManager.removeFile(for: url)
    }
    
    /// Очищает кеш для всех видео жеста
    /// - Parameters:
    ///   - signId: ID жеста (для логирования)
    ///   - videos: Массив видео
    func clearCache(for signId: String, videos: [SignVideo]) {
        for video in videos {
            clearCache(for: video)
        }
        logger.info("🗑️ Кеш для жеста \(signId) очищен (\(videos.count) видео)")
    }
    
    /// Полностью очищает весь кеш видео
    func clearAllCache() {
        directoryManager.clearAllCache()
    }
    
    // MARK: - Cache Size Management
    
    /// Возвращает текущий размер кеша на диске в байтах
    /// - Returns: Размер в байтах
    func getCacheSize() -> Int {
        return directoryManager.getCacheSize()
    }
    
    /// Проверяет и поддерживает лимит размера кеша
    func ensureCacheLimit() {
        directoryManager.ensureCacheLimit()
    }
}
