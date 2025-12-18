import Foundation
import os.log

/// Репозиторий для работы с видео из Supabase Storage
///
/// Поддерживает двухуровневое кеширование:
/// - **Долгосрочный кеш**: файлы на диске для избранных жестов (до 500MB)
/// - **Краткосрочный кеш**: AVPlayer автоматически кеширует в памяти
///
/// ⚠️ **Важно**: Краткосрочный кеш AVPlayer хранится только в оперативной памяти
/// и не сохраняется между запусками приложения. После перезапуска приложения
/// для просмотра видео не избранных жестов требуется активное интернет-соединение.
final class VideoRepository: VideoRepositoryProtocol {
    // MARK: - Constants
    
    private enum Constants {
        /// Максимальное количество URL в кеше
        static let cacheCountLimit: Int = 100
        /// Максимальный размер кеша в байтах (10 МБ)
        static let cacheTotalCostLimit: Int = 10 * 1024 * 1024
    }
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.videoRepository", category: "VideoRepository")
    
    /// Кэш для URL видео (краткосрочный, в памяти)
    private let cache = NSCache<NSString, NSURL>()
    
    /// Очередь для thread-safe операций
    private let cacheQueue = DispatchQueue(label: "com.rsl.videoRepository.cache")
    
    /// Сервис кеширования видео
    private let videoCacheService: VideoCacheServiceProtocol
    
    /// Монитор сети для проверки доступности интернета
    private let networkMonitor: NetworkMonitorProtocol
    
    // MARK: - Initialization
    
    init(
        videoCacheService: VideoCacheServiceProtocol = VideoCacheService.shared,
        networkMonitor: NetworkMonitorProtocol = NetworkMonitor()
    ) {
        self.videoCacheService = videoCacheService
        self.networkMonitor = networkMonitor
        
        // Настройка кэша
        cache.countLimit = Constants.cacheCountLimit
        cache.totalCostLimit = Constants.cacheTotalCostLimit
    }
    
    // MARK: - VideoRepositoryProtocol
    
    func getVideoURL(for sign: Sign) async throws -> URL {
        // Используем первое видео из массива (новый формат)
        if let firstVideo = sign.videos?.first {
            return try await getVideoURL(for: firstVideo, useFavoritesCache: false)
        }
        
        // Fallback на старый формат (обратная совместимость)
        let cacheKey = sign.id as NSString
        if let cachedURL = cacheQueue.sync(execute: { cache.object(forKey: cacheKey) as URL? }) {
            return cachedURL
        }
        
        // Используем публичный URL из модели Sign (старый формат)
        guard let supabaseUrl = sign.supabaseUrl, let url = URL(string: supabaseUrl) else {
            throw VideoRepositoryError.invalidURL
        }
        
        // Сохранение в кэш
        cacheQueue.sync {
            cache.setObject(url as NSURL, forKey: cacheKey)
        }
        
        return url
    }
    
    func getVideoURL(for video: SignVideo, useFavoritesCache: Bool = false) async throws -> URL {
        guard let url = URL(string: video.url) else {
            throw VideoRepositoryError.invalidURL
        }
        
        let videoId = String(video.id)
        
        if useFavoritesCache {
            // Долгосрочный кеш для избранных жестов (файлы на диске)
            return try await getVideoURLFromFavoritesCache(url: url, videoId: videoId, video: video)
        } else {
            // Краткосрочный кеш (AVPlayer в памяти)
            return try await getVideoURLWithShortTermCache(url: url, video: video)
        }
    }
    
    func preloadVideo(for sign: Sign) async throws {
        // Загрузка URL в кэш
        _ = try await getVideoURL(for: sign)
    }
    
    func preloadVideo(video: SignVideo, useFavoritesCache: Bool = true) async throws {
        if useFavoritesCache {
            logger.info("📥 Предзагрузка видео \(video.id) в долгосрочный кеш")
            await videoCacheService.preloadVideo(video)
        } else {
            // Для краткосрочного кеша просто получаем URL
            _ = try await getVideoURL(for: video, useFavoritesCache: false)
        }
    }
    
    func clearCache() {
        cacheQueue.sync {
            cache.removeAllObjects()
        }
        logger.info("🗑️ Краткосрочный кеш URL очищен")
    }
    
    // MARK: - Private Methods
    
    /// Получает URL видео из долгосрочного кеша (для избранных жестов)
    /// Если видео есть в кеше - возвращает URL локального файла
    /// Если нет - загружает и сохраняет в файл
    /// - Parameters:
    ///   - url: URL видео на сервере
    ///   - videoId: ID видео
    ///   - video: Модель видео
    /// - Returns: URL видео (локальный файл или оригинальный URL)
    /// - Throws: VideoRepositoryError
    private func getVideoURLFromFavoritesCache(url: URL, videoId: String, video: SignVideo) async throws -> URL {
        // Проверяем наличие в файловом кеше
        if let cachedFileURL = videoCacheService.getCachedVideoURL(video) {
            logger.info("✅ Видео \(videoId) загружено из файлового кеша")
            return cachedFileURL
        }
        
        // Если нет в кеше, проверяем интернет
        let isConnected = await networkMonitor.checkConnection()
        if !isConnected {
            logger.warning("⚠️ Видео \(videoId) не найдено в кеше и нет интернета")
            throw VideoRepositoryError.videoNotCached
        }
        
        // Загружаем и сохраняем видео в файловый кеш
        logger.info("📥 Загрузка видео \(videoId) с сервера в файловый кеш...")
        
        do {
            let cachedFileURL = try await videoCacheService.downloadAndCache(video: video)
            logger.info("✅ Видео \(videoId) сохранено в файловый кеш")
            return cachedFileURL
        } catch {
            logger.error("❌ Ошибка загрузки видео \(videoId): \(error.localizedDescription)")
            throw VideoRepositoryError.downloadFailed
        }
    }
    
    /// Получает URL видео с краткосрочным кешированием (AVPlayer в памяти)
    /// - Parameters:
    ///   - url: URL видео
    ///   - video: Модель видео
    /// - Returns: URL видео
    /// - Throws: VideoRepositoryError
    private func getVideoURLWithShortTermCache(url: URL, video: SignVideo) async throws -> URL {
        let cacheKey = "video_\(video.id)" as NSString
        
        // Проверка кэша URL
        if let cachedURL = cacheQueue.sync(execute: { cache.object(forKey: cacheKey) as URL? }) {
            logger.debug("✅ URL видео \(video.id) из краткосрочного кеша")
            return cachedURL
        }
        
        // Для не избранных жестов проверяем интернет обязательно
        // Краткосрочный кеш AVPlayer не сохраняется между запусками приложения
        let isConnected = await networkMonitor.checkConnection()
        if !isConnected {
            logger.warning("⚠️ Нет интернета для загрузки видео \(video.id) (не в избранном)")
            throw VideoRepositoryError.noInternetConnection
        }
        
        // Сохранение URL в краткосрочный кэш
        cacheQueue.sync {
            cache.setObject(url as NSURL, forKey: cacheKey)
        }
        
        logger.debug("📥 URL видео \(video.id) готов для AVPlayer (краткосрочный кеш)")
        
        // AVPlayer автоматически кеширует видео в памяти при воспроизведении
        // cachePolicy .useProtocolCachePolicy позволяет AVPlayer использовать свой встроенный кеш
        return url
    }
}
