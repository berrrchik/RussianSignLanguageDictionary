import Foundation
import os.log

/// Репозиторий для работы с видео из Supabase Storage
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
final class VideoRepository: VideoRepositoryProtocol {
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
    
    // MARK: - Initialization
    
    init(
        videoCacheService: VideoCacheServiceProtocol,
        networkMonitor: NetworkMonitorProtocol
    ) {
        self.videoCacheService = videoCacheService
        self.networkMonitor = networkMonitor
        
        // Настройка NSCache (хранит маппинг video_id → локальный file URL)
        cache.countLimit = Constants.cacheCountLimit
        
        // Создание директории для краткосрочного кеша в Caches/
        // cachesDirectory — штатное место для кешей в iOS:
        // - Сохраняется между обычными сессиями приложения
        // - Может быть очищена системой при нехватке места (что допустимо для кеша)
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Constants.shortTermCacheDirectoryName, isDirectory: true)
        self.shortTermCacheDirectory = cacheDir
        
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        // LRU-очистка в фоне (не блокируем main thread при холодном старте)
        DispatchQueue.global(qos: .utility).async {
            let removedCount = FileCacheLRU.enforceSizeLimit(
                at: cacheDir,
                maxSize: Constants.maxShortTermCacheSize,
                targetPercent: Constants.targetSizePercent
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
        let cacheKey = "video_\(video.id)" as NSString
        
        // 1. Проверяем NSCache (быстрый путь, O(1))
        // NSCache потокобезопасен — дополнительная синхронизация не нужна
        if let cachedURL = cache.object(forKey: cacheKey) as URL?,
           FileManager.default.fileExists(atPath: cachedURL.path) {
            // Обновляем дату модификации для корректной работы LRU-алгоритма:
            // без этого файлы, к которым обращаются часто, могут быть удалены
            // раньше реально «старых» файлов
            touchFile(at: cachedURL)
            return cachedURL
        }
        
        // 2. NSCache мог evict запись — проверяем файл на диске по имени
        let cachedFileURL = shortTermCacheDirectory.appendingPathComponent("video_\(video.id).mp4")
        if FileManager.default.fileExists(atPath: cachedFileURL.path) {
            // Восстанавливаем запись в NSCache и обновляем дату для LRU
            cache.setObject(cachedFileURL as NSURL, forKey: cacheKey)
            touchFile(at: cachedFileURL)
            return cachedFileURL
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
        guard let url = URL(string: video.url) else {
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
        guard let url = URL(string: lesson.videoUrl) else {
            logger.error("❌ Lesson video: невалидный URL для урока \(lesson.id) (\(lesson.videoUrl))")
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
        } catch let error as VideoCacheError {
            throw VideoRepositoryError.from(error)
        } catch {
            logger.error("❌ Ошибка загрузки видео \(videoId): \(error.localizedDescription)")
            throw VideoRepositoryError.downloadFailed
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
            guard let self = self else { throw VideoRepositoryError.downloadFailed }
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
        // 1. Проверяем интернет
        let isConnected = await networkMonitor.checkConnection()
        if !isConnected {
            logger.warning("⚠️ Нет интернета для загрузки видео \(video.id) (не в избранном)")
            throw VideoRepositoryError.noInternetConnection
        }
        
        // 2. Скачиваем видео
        logger.debug("📥 Загрузка видео \(video.id) в краткосрочный кеш...")
        
        do {
            let (tempDownloadURL, _) = try await URLSession.shared.download(from: url)
            
            // 3. Перемещаем в управляемую директорию
            let localFileURL = shortTermCacheDirectory.appendingPathComponent("video_\(video.id).mp4")
            
            // Удаляем старый файл если есть
            try? FileManager.default.removeItem(at: localFileURL)
            try FileManager.default.moveItem(at: tempDownloadURL, to: localFileURL)
            
            // 4. Сохраняем в NSCache (потокобезопасен, синхронизация не нужна)
            let cacheKey = "video_\(video.id)" as NSString
            cache.setObject(localFileURL as NSURL, forKey: cacheKey)
            
            logger.debug("✅ Видео \(video.id) сохранено в краткосрочный кеш")
            
            // 5. Проверяем лимит кеша (LRU-очистка в фоне)
            ensureShortTermCacheLimit()
            
            return localFileURL
        } catch {
            logger.error("❌ Ошибка загрузки видео \(video.id) с \(url): \(error.localizedDescription)")
            throw VideoRepositoryError.downloadFailed
        }
    }
    
    // MARK: - Cache Maintenance
    
    /// Очищает все файлы краткосрочного кеша
    private func clearShortTermCacheDirectory() {
        let fileManager = FileManager.default
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
        DispatchQueue.global(qos: .utility).async { [shortTermCacheDirectory] in
            FileCacheLRU.enforceSizeLimit(
                at: shortTermCacheDirectory,
                maxSize: Constants.maxShortTermCacheSize,
                targetPercent: Constants.targetSizePercent
            )
        }
    }
    
    /// Обновляет дату модификации файла для корректной работы LRU
    ///
    /// LRU-алгоритм сортирует файлы по `contentModificationDate`.
    /// Без обновления даты при чтении часто используемые файлы могут быть
    /// удалены раньше реально «забытых».
    private func touchFile(at url: URL) {
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: url.path
        )
    }
}
