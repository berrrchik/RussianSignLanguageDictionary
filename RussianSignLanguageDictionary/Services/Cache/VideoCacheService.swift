import Foundation
import os.log

/// Сервис для управления **долгосрочным** кешем видео (избранные жесты)
///
/// Хранит видео на диске в директории `Caches/favorites_videos/` с лимитом 500MB.
/// Используется `VideoRepository` для кеширования видео избранных жестов.
///
/// > Краткосрочный кеш (для обычного просмотра) управляется отдельно
/// > в `VideoRepository` через `Caches/video_short_term_cache/` (LRU, до 150MB).
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
        downloader: VideoCacheDownloader? = nil,
        networkMonitor: NetworkMonitorProtocol = NetworkMonitor()
    ) {
        let manager = directoryManager ?? VideoCacheDirectoryManager()
        self.directoryManager = manager
        self.downloader = downloader ?? VideoCacheDownloader(
            directoryManager: manager,
            networkMonitor: networkMonitor
        )
        logger.info("✅ VideoCacheService инициализирован")
    }
    
    // MARK: - Cache Checking
    
    /// Проверяет наличие видео в кеше
    /// - Parameter video: Видео для проверки
    /// - Returns: true если видео есть в кеше
    func isVideoCached(_ video: SignVideo) -> Bool {
        guard let url = APIConfig.videoURL(forPath: video.url) else { return false }
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
        guard let url = APIConfig.videoURL(forPath: video.url) else { return nil }
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

    func promoteCachedVideo(_ video: SignVideo, from localFileURL: URL) throws -> URL {
        guard let originalURL = APIConfig.videoURL(forPath: video.url) else {
            throw VideoCacheError.invalidURL
        }

        let videoId = directoryManager.videoId(from: originalURL)
        guard let targetURL = directoryManager.cacheFileURL(for: videoId) else {
            throw VideoCacheError.cacheDirectoryNotAvailable
        }

        try directoryManager.copyItem(from: localFileURL, to: targetURL)
        logger.info("📦 Видео \(video.id) перенесено из краткосрочного кеша в durable-кеш")
        directoryManager.ensureCacheLimit()
        return targetURL
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
        guard let url = APIConfig.videoURL(forPath: video.url) else { return }
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
