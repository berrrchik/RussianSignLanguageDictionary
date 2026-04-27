import Foundation
import os.log

/// Репозиторий для работы с видео с сервера
///
/// Поддерживает двухуровневое кеширование:
/// - **Долгосрочный кеш**: файлы на диске для избранных жестов (до 500MB)
/// - **Краткосрочный кеш**: видео скачиваются в `Caches/video_short_term_cache/`,
///   управляются по стратегии LRU (Least Recently Used) с лимитом размера
///
/// Краткосрочный кеш хранится в `cachesDirectory` — штатное место для кешей iOS.
/// Система может очистить его при нехватке места, но между обычными сессиями
/// кеш сохраняется, обеспечивая мгновенный доступ к ранее просмотренным видео.
/// При превышении лимита (150MB) автоматически удаляются самые старые файлы.
///
/// **Performance Monitoring**: Операции загрузки видео отслеживаются через Firebase Performance Monitoring:
/// - `video_load_favorites_cache` - загрузка из долгосрочного кеша избранных
/// - `video_download_network` - загрузка видео с сервера в краткосрочный кеш
final class VideoRepository: VideoRepositoryProtocol {
    typealias CacheLimitEnforcer = (URL, Int, Int) -> Int

    // MARK: - Constants
    
    private enum Constants {
        /// Максимальное количество записей в NSCache
        static let cacheCountLimit: Int = 100
        /// Название директории для краткосрочного кеша
        static let shortTermCacheDirectoryName = "video_short_term_cache"
        /// Максимальный размер краткосрочного кеша на диске (150 MB)
        static let maxShortTermCacheSize: Int = 150 * 1024 * 1024
        /// Целевой размер после очистки LRU (80% от лимита = 120 MB)
        static let targetSizePercent: Int = 80
    }
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.videoRepository", category: "VideoRepository")
    
    /// Кэш для локальных URL видео (in-memory, быстрый lookup)
    /// Маппинг: video_id → file URL в Caches/
    /// NSCache потокобезопасен — дополнительная синхронизация не требуется
    private let cache = NSCache<NSString, NSURL>()
    
    /// Сервис кеширования видео (для долгосрочного кеша избранных)
    private let videoCacheService: VideoCacheServiceProtocol
    
    /// Монитор сети для проверки доступности интернета
    private let networkMonitor: NetworkMonitorProtocol
    
    /// Директория для файлов краткосрочного кеша (Caches/)
    private let shortTermCacheDirectory: URL
    
    /// Координатор активных загрузок для дедупликации параллельных запросов
    /// Использует Swift actor для потокобезопасности без блокировки потоков
    private let downloadCoordinator = VideoDownloadCoordinator()

    /// FileManager для работы с файлами краткосрочного кеша
    private let fileManager: FileManager

    /// URLSession для загрузки видео в краткосрочный кеш
    private let session: URLSession

    /// Алгоритм LRU-очистки, подменяемый в тестах
    private let cacheLimitEnforcer: CacheLimitEnforcer
    
    // MARK: - Initialization
    
    init(
        videoCacheService: VideoCacheServiceProtocol,
        networkMonitor: NetworkMonitorProtocol,
        fileManager: FileManager = .default,
        session: URLSession? = nil,
        shortTermCacheDirectory: URL? = nil,
        cacheLimitEnforcer: @escaping CacheLimitEnforcer = FileCacheLRU.enforceSizeLimit
    ) {
        self.videoCacheService = videoCacheService
        self.networkMonitor = networkMonitor
        self.fileManager = fileManager
        self.session = session ?? VideoSessionFactory.makeSession()
        self.cacheLimitEnforcer = cacheLimitEnforcer
        
        // Настройка NSCache (хранит маппинг video_id → локальный file URL)
        cache.countLimit = Constants.cacheCountLimit
        
        // Создание директории для краткосрочного кеша в Caches/
        // cachesDirectory — штатное место для кешей в iOS:
        // - Сохраняется между обычными сессиями приложения
        // - Может быть очищена системой при нехватке места (что допустимо для кеша)
        let cacheDir = shortTermCacheDirectory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Constants.shortTermCacheDirectoryName, isDirectory: true)
        self.shortTermCacheDirectory = cacheDir
        
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        // LRU-очистка в фоне (не блокируем main thread при холодном старте)
        DispatchQueue.global(qos: .utility).async {
            let removedCount = cacheLimitEnforcer(
                cacheDir,
                Constants.maxShortTermCacheSize,
                Constants.targetSizePercent
            )
            if removedCount > 0 {
                Logger(subsystem: "com.rsl.videoRepository", category: "VideoRepository")
                    .info("🗑️ LRU-очистка при старте: удалено \(removedCount) файлов")
            }
        }
        
        logger.info("✅ VideoRepository инициализирован, cache: \(cacheDir.path)")
    }
    
    // MARK: - VideoRepositoryProtocol
    
    func cachedVideoURL(for video: SignVideo) -> URL? {
        if let shortTermURL = shortTermCachedVideoURL(for: video) {
            return shortTermURL
        }
        
        // 3. Проверяем долгосрочный кеш (избранное, файлы на диске)
        if let favoritesURL = videoCacheService.getCachedVideoURL(video) {
            return favoritesURL
        }
        
        return nil
    }
    
    func getVideoURL(for sign: Sign) async throws -> URL {
        guard let firstVideo = sign.videos?.first else {
            throw VideoRepositoryError.invalidURL
        }
        
        return try await getVideoURL(for: firstVideo, useFavoritesCache: false)
    }
    
    func getVideoURL(for video: SignVideo, useFavoritesCache: Bool = false) async throws -> URL {
        guard let url = APIConfig.videoURL(forPath: video.url) else {
            throw VideoRepositoryError.invalidURL
        }
        
        let videoId = String(video.id)
        
        if useFavoritesCache {
            // Долгосрочный кеш для избранных жестов (файлы на диске)
            return try await getVideoURLFromFavoritesCache(url: url, videoId: videoId, video: video)
        } else {
            // Краткосрочный кеш (файлы в Caches/)
            return try await getVideoURLWithShortTermCache(url: url, video: video)
        }
    }
    
    func getVideoURL(for lesson: Lesson) async throws -> URL {
        guard let url = APIConfig.videoURL(forPath: lesson.videoUrl) else {
            logger.error("❌ Lesson video: невалидный путь для урока \(lesson.id) (\(lesson.videoUrl))")
            throw VideoRepositoryError.invalidURL
        }
        
        let isConnected = await networkMonitor.checkConnection()
        if !isConnected {
            logger.warning("⚠️ Lesson video: нет интернета для загрузки видео урока \(lesson.id)")
            throw VideoRepositoryError.noInternetConnection
        }
        
        return url
    }
    
    func preloadVideo(for sign: Sign) async throws {
        // Загрузка видео в кэш
        _ = try await getVideoURL(for: sign)
    }
    
    func preloadVideo(video: SignVideo, useFavoritesCache: Bool = true) async throws {
        if useFavoritesCache {
            logger.info("📥 Предзагрузка видео \(video.id) в долгосрочный кеш")
            await videoCacheService.preloadVideo(video)
        } else {
            // Для краткосрочного кеша — скачиваем в temp
            _ = try await getVideoURL(for: video, useFavoritesCache: false)
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
        clearShortTermCacheDirectory()
        logger.info("🗑️ Краткосрочный кеш очищен (NSCache + файлы)")
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
        let trace = PerformanceService.startTrace("video_load_favorites_cache")
        PerformanceService.addAttribute(trace, name: "video_id", value: videoId)
        defer { PerformanceService.stopTrace(trace) }
        
        // Проверяем наличие в файловом кеше
        if let cachedFileURL = videoCacheService.getCachedVideoURL(video) {
            logger.info("✅ Видео \(videoId) загружено из файлового кеша")
            PerformanceService.addAttribute(trace, name: "source", value: "cache")
            return cachedFileURL
        }

        if let shortTermFileURL = shortTermCachedVideoURL(for: video) {
            do {
                let promotedURL = try videoCacheService.promoteCachedVideo(video, from: shortTermFileURL)
                logger.info("✅ Видео \(videoId) перенесено из краткосрочного кеша в избранное")
                PerformanceService.addAttribute(trace, name: "source", value: "short_term_promotion")
                return promotedURL
            } catch {
                logger.warning("⚠️ Не удалось перенести видео \(videoId) из краткосрочного кеша: \(error.localizedDescription)")
            }
        }
        
        // Если нет в кеше, проверяем интернет
        let isConnected = await networkMonitor.checkConnection()
        if !isConnected {
            logger.warning("⚠️ Видео \(videoId) не найдено в кеше и нет интернета")
            PerformanceService.addAttribute(trace, name: "error", value: "no_internet")
            throw VideoRepositoryError.noInternetConnection
        }
        
        // Загружаем и сохраняем видео в файловый кеш
        logger.info("📥 Загрузка видео \(videoId) с сервера в файловый кеш...")
        PerformanceService.addAttribute(trace, name: "source", value: "network")
        
        do {
            let cachedFileURL = try await videoCacheService.downloadAndCache(video: video)
            logger.info("✅ Видео \(videoId) сохранено в файловый кеш")
            
            // Добавляем метрику размера файла, если доступна
            if let fileSize = try? cachedFileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                PerformanceService.incrementMetric(trace, name: "video_size_bytes", by: Int64(fileSize))
            }
            
            return cachedFileURL
        } catch let error as VideoCacheError {
            PerformanceService.addAttribute(trace, name: "error", value: error.localizedDescription)
            throw VideoRepositoryError.from(error)
        } catch {
            logger.error("❌ Ошибка загрузки видео \(videoId): \(error.localizedDescription)")
            PerformanceService.addAttribute(trace, name: "error", value: error.localizedDescription)
            throw mapVideoError(error)
        }
    }
    
    /// Получает URL видео с краткосрочным кешированием (файлы в Caches/)
    ///
    /// При первом запросе скачивает видео в локальный файл.
    /// При повторном запросе возвращает локальный URL мгновенно.
    /// Параллельные запросы для одного video.id дедуплицируются:
    /// второй вызов ждёт завершения первого, а не запускает повторную загрузку.
    /// - Parameters:
    ///   - url: URL видео на сервере
    ///   - video: Модель видео
    /// - Returns: URL локального файла
    /// - Throws: VideoRepositoryError
    private func getVideoURLWithShortTermCache(url: URL, video: SignVideo) async throws -> URL {
        // 1. Проверяем кеш (синхронно)
        if let localURL = cachedVideoURL(for: video) {
            logger.debug("✅ Видео \(video.id) из краткосрочного кеша (локальный файл)")
            return localURL
        }
        
        // 2. Получаем или создаём задачу загрузки через actor (не блокирует поток!)
        let (task, isExisting) = await downloadCoordinator.getOrCreateTask(videoId: video.id) { [weak self] in
            guard let self = self else { throw VideoRepositoryError.videoUnavailable }
            return try await self.downloadAndCacheVideo(url: url, video: video)
        }
        
        // 3. Если это существующая задача, логируем
        if isExisting {
            logger.debug("⏳ Видео \(video.id) уже загружается, ожидаем...")
        }
        
        return try await task.value
    }
    
    /// Выполняет загрузку видео и сохранение в краткосрочный кеш
    /// - Parameters:
    ///   - url: URL видео на сервере
    ///   - video: Модель видео
    /// - Returns: URL локального файла
    /// - Throws: VideoRepositoryError
    private func downloadAndCacheVideo(url: URL, video: SignVideo) async throws -> URL {
        let trace = PerformanceService.startTrace("video_download_network")
        PerformanceService.addAttribute(trace, name: "video_id", value: String(video.id))
        PerformanceService.addAttribute(trace, name: "cache_type", value: "short_term")
        defer { PerformanceService.stopTrace(trace) }
        
        let isConnected = await networkMonitor.checkConnection()
        guard isConnected else {
            logger.warning("⚠️ Нет интернета для загрузки видео \(video.id) (не в избранном)")
            PerformanceService.addAttribute(trace, name: "error", value: "no_internet")
            throw VideoRepositoryError.noInternetConnection
        }
        
        logger.debug("📥 Загрузка видео \(video.id) в краткосрочный кеш...")
        
        do {
            let tempURL = try await downloadToTemp(from: url)
            let localURL = try moveToCache(tempURL: tempURL, videoId: video.id)
            updateInMemoryCache(localURL: localURL, videoId: video.id)
            
            if let fileSize = try? localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                PerformanceService.incrementMetric(trace, name: "video_size_bytes", by: Int64(fileSize))
            }
            
            ensureShortTermCacheLimit()
            return localURL
        } catch {
            logger.error("❌ Ошибка загрузки видео \(video.id) с \(url): \(error.localizedDescription)")
            PerformanceService.addAttribute(trace, name: "error", value: error.localizedDescription)
            CrashlyticsErrorReporter.capture(
                error,
                context: ["videoId": "\(video.id)", "url": url.absoluteString],
                subsystem: "com.rsl.videoRepository"
            )
            throw mapVideoError(error)
        }
    }
    
    private func downloadToTemp(from url: URL) async throws -> URL {
        let (tempURL, response) = try await session.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoRepositoryError.videoUnavailable
        }
        return tempURL
    }
    
    private func moveToCache(tempURL: URL, videoId: Int) throws -> URL {
        let localFileURL = shortTermCacheDirectory.appendingPathComponent("video_\(videoId).mp4")
        try? fileManager.removeItem(at: localFileURL)
        try fileManager.moveItem(at: tempURL, to: localFileURL)
        logger.debug("✅ Видео \(videoId) сохранено в краткосрочный кеш")
        return localFileURL
    }
    
    private func updateInMemoryCache(localURL: URL, videoId: Int) {
        let cacheKey = "video_\(videoId)" as NSString
        cache.setObject(localURL as NSURL, forKey: cacheKey)
    }

    private func shortTermCachedVideoURL(for video: SignVideo) -> URL? {
        let cacheKey = "video_\(video.id)" as NSString

        if let cachedURL = cache.object(forKey: cacheKey) as URL?,
           fileManager.fileExists(atPath: cachedURL.path) {
            touchFile(at: cachedURL)
            return cachedURL
        }

        let cachedFileURL = shortTermCacheDirectory.appendingPathComponent("video_\(video.id).mp4")
        if fileManager.fileExists(atPath: cachedFileURL.path) {
            cache.setObject(cachedFileURL as NSURL, forKey: cacheKey)
            touchFile(at: cachedFileURL)
            return cachedFileURL
        }

        return nil
    }
    
    // MARK: - Cache Maintenance
    
    /// Очищает все файлы краткосрочного кеша
    private func clearShortTermCacheDirectory() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: shortTermCacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        
        for fileURL in contents {
            try? fileManager.removeItem(at: fileURL)
        }
        logger.debug("🗑️ Краткосрочный кеш очищен (\(contents.count) файлов)")
    }
    
    /// Проверяет лимит краткосрочного кеша и запускает LRU-очистку в фоне
    private func ensureShortTermCacheLimit() {
        DispatchQueue.global(qos: .utility).async { [shortTermCacheDirectory, cacheLimitEnforcer] in
            _ = cacheLimitEnforcer(
                shortTermCacheDirectory,
                Constants.maxShortTermCacheSize,
                Constants.targetSizePercent
            )
        }
    }
    
    /// Обновляет дату модификации файла для корректной работы LRU
    ///
    /// LRU-алгоритм сортирует файлы по `contentModificationDate`.
    /// Без обновления даты при чтении часто используемые файлы могут быть
    /// удалены раньше реально «забытых».
    private func touchFile(at url: URL) {
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: url.path
        )
    }

    private func mapVideoError(_ error: Error) -> VideoRepositoryError {
        if let repositoryError = error as? VideoRepositoryError {
            return repositoryError
        }

        if let cacheError = error as? VideoCacheError {
            return VideoRepositoryError.from(cacheError)
        }

        guard let urlError = error as? URLError else {
            return .videoUnavailable
        }

        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noInternetConnection
        case .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .badServerResponse:
            return .videoUnavailable
        default:
            return .videoUnavailable
        }
    }
}
