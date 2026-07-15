import Foundation
import os.log

// MARK: - Protocol

/// Управляет краткосрочным LRU-кешем видео в `Caches/video_short_term_cache/`.
///
/// Краткосрочный кеш сохраняется между сессиями приложения, но может быть очищен
/// системой при нехватке места. При превышении лимита (150 MB) удаляются наиболее
/// давно использованные файлы.
protocol ShortTermVideoCacheManagerProtocol: Sendable {
    /// Синхронная проверка кеша (NSCache + файловая система).
    /// Обновляет дату модификации файла для корректной LRU-сортировки.
    func cachedVideoURL(for video: SignVideo) -> URL?

    /// Загружает видео с сервера и сохраняет в краткосрочный кеш.
    /// Параллельные запросы для одного `video.id` дедуплицируются — второй вызов
    /// ждёт завершения первого, не запуская повторную загрузку.
    /// - Throws: `VideoRepositoryError`
    func downloadVideo(url: URL, video: SignVideo) async throws -> URL

    /// Очищает NSCache и все файлы краткосрочного кеша.
    func clear()
}

// MARK: - Implementation

/// `@unchecked Sendable`: все stored properties — `let` (никогда не мутируются после `init`).
/// `NSCache` потокобезопасен сам по себе, но не аннотирован `Sendable` в Foundation.
/// `FileManager.default`-совместимые вызовы (`fileExists`, `setAttributes`, etc.) документированы
/// Apple как потокобезопасные для этого набора операций. Фоновая LRU-очистка (`Task(priority: .utility)`)
/// работает только с локальными `URL`/`@Sendable`-замыканием — без доступа к shared mutable state.
final class ShortTermVideoCacheManager: ShortTermVideoCacheManagerProtocol, @unchecked Sendable {

    // MARK: - Types

    typealias CacheLimitEnforcer = @Sendable (URL, Int, Int) -> Int

    // MARK: - Constants

    private enum Constants {
        static let directoryName = "video_short_term_cache"
        static let memCacheCountLimit = 100
        static let maxDiskCacheSize = 150 * 1024 * 1024  // 150 MB
        static let targetSizePercent = 80
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.rsl.videoCache", category: "ShortTermVideoCacheManager")

    /// In-memory маппинг video_id → file URL. NSCache потокобезопасен.
    private let memoryCache = NSCache<NSString, NSURL>()

    private let networkMonitor: NetworkMonitorProtocol
    private let fileManager: FileManager
    private let session: URLSession
    private let cacheDirectory: URL
    private let cacheLimitEnforcer: CacheLimitEnforcer

    /// Дедуплицирует параллельные загрузки одного видео через Swift actor
    private let downloadCoordinator = VideoDownloadCoordinator()

    // MARK: - Init

    init(
        networkMonitor: NetworkMonitorProtocol,
        fileManager: FileManager = .default,
        session: URLSession? = nil,
        cacheDirectory: URL? = nil,
        cacheLimitEnforcer: @escaping CacheLimitEnforcer = FileCacheLRU.enforceSizeLimit
    ) {
        self.networkMonitor = networkMonitor
        self.fileManager = fileManager
        self.session = session ?? VideoSessionFactory.makeSession()
        self.cacheLimitEnforcer = cacheLimitEnforcer

        memoryCache.countLimit = Constants.memCacheCountLimit

        let baseCacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.cacheDirectory = cacheDirectory
            ?? baseCacheDir.appendingPathComponent(Constants.directoryName, isDirectory: true)

        try? fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)

        // LRU-очистка в фоне при холодном старте (не блокируем main thread)
        let dir = self.cacheDirectory
        let enforcer = cacheLimitEnforcer
        let startupLogger = Logger(subsystem: "com.rsl.videoCache", category: "ShortTermVideoCacheManager")
        Task(priority: .utility) {
            let removed = enforcer(dir, Constants.maxDiskCacheSize, Constants.targetSizePercent)
            if removed > 0 {
                startupLogger.info("🗑️ LRU-очистка при старте: удалено \(removed) файлов")
            }
        }

        logger.info("✅ ShortTermVideoCacheManager инициализирован, dir: \(self.cacheDirectory.path)")
    }

    // MARK: - ShortTermVideoCacheManagerProtocol

    func cachedVideoURL(for video: SignVideo) -> URL? {
        let key = cacheKey(for: video.id)

        if let cached = memoryCache.object(forKey: key) as URL?,
           fileManager.fileExists(atPath: cached.path) {
            touchFile(at: cached)
            return cached
        }

        let diskURL = diskFileURL(for: video.id)
        if fileManager.fileExists(atPath: diskURL.path) {
            memoryCache.setObject(diskURL as NSURL, forKey: key)
            touchFile(at: diskURL)
            return diskURL
        }

        return nil
    }

    func downloadVideo(url: URL, video: SignVideo) async throws -> URL {
        // 1. Синхронная проверка кеша — NSCache + диск (без сетевого запроса)
        if let cached = cachedVideoURL(for: video) {
            logger.debug("✅ Видео \(video.id) из краткосрочного кеша")
            return cached
        }

        // 2. Создаём или присоединяемся к существующей задаче загрузки
        let (task, isExisting) = await downloadCoordinator.getOrCreateTask(videoId: video.id) { [weak self] in
            guard let self else { throw VideoRepositoryError.videoUnavailable }
            return try await self.fetchAndStore(url: url, video: video)
        }

        if isExisting {
            logger.debug("⏳ Видео \(video.id) уже загружается, ожидаем...")
        }

        return try await task.value
    }

    func clear() {
        memoryCache.removeAllObjects()
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        contents.forEach { try? fileManager.removeItem(at: $0) }
        logger.debug("🗑️ Краткосрочный кеш очищен (\(contents.count) файлов)")
    }

    // MARK: - Private

    private func fetchAndStore(url: URL, video: SignVideo) async throws -> URL {
        let trace = PerformanceService.startTrace("video_download_network")
        PerformanceService.addAttribute(trace, name: "video_id", value: String(video.id))
        PerformanceService.addAttribute(trace, name: "cache_type", value: "short_term")
        defer { PerformanceService.stopTrace(trace) }

        guard await networkMonitor.checkConnection() else {
            logger.warning("⚠️ Нет интернета для загрузки видео \(video.id) (не в избранном)")
            PerformanceService.addAttribute(trace, name: "error", value: "no_internet")
            throw VideoRepositoryError.noInternetConnection
        }

        logger.debug("📥 Загрузка видео \(video.id) в краткосрочный кеш...")

        do {
            let tempURL = try await downloadToTemp(from: url)
            let localURL = try moveToCache(tempURL: tempURL, videoId: video.id)
            memoryCache.setObject(localURL as NSURL, forKey: cacheKey(for: video.id))

            if let fileSize = try? localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                PerformanceService.incrementMetric(trace, name: "video_size_bytes", by: Int64(fileSize))
            }

            enforceCacheLimitInBackground()
            return localURL
        } catch {
            logger.error("❌ Ошибка загрузки видео \(video.id) с \(url): \(error.localizedDescription)")
            PerformanceService.addAttribute(trace, name: "error", value: error.localizedDescription)
            CrashlyticsErrorReporter.capture(
                error,
                context: ["videoId": "\(video.id)", "url": url.absoluteString],
                subsystem: "com.rsl.videoRepository"
            )
            throw mapError(error)
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
        let localURL = diskFileURL(for: videoId)
        try? fileManager.removeItem(at: localURL)
        try fileManager.moveItem(at: tempURL, to: localURL)
        logger.debug("✅ Видео \(videoId) сохранено в краткосрочный кеш")
        return localURL
    }

    private func enforceCacheLimitInBackground() {
        let dir = cacheDirectory
        let enforcer = cacheLimitEnforcer
        Task(priority: .utility) {
            _ = enforcer(dir, Constants.maxDiskCacheSize, Constants.targetSizePercent)
        }
    }

    private func touchFile(at url: URL) {
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: url.path
        )
    }

    private func cacheKey(for videoId: Int) -> NSString {
        "video_\(videoId)" as NSString
    }

    private func diskFileURL(for videoId: Int) -> URL {
        cacheDirectory.appendingPathComponent("video_\(videoId).mp4")
    }

    private func mapError(_ error: Error) -> VideoRepositoryError {
        if let e = error as? VideoRepositoryError { return e }
        guard let urlError = error as? URLError else { return .videoUnavailable }
        switch URLErrorClassifier.classify(urlError) {
        case .noInternet: return .noInternetConnection
        case .unavailable: return .videoUnavailable
        }
    }
}
