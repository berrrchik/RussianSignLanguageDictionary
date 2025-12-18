import Foundation
import os.log
import CryptoKit

/// Сервис для управления кешем видео
/// 
/// Обеспечивает двухуровневое кеширование:
/// - **Долгосрочный кеш (файлы на диске)**: для избранных жестов, сохраняется до 500MB
/// - **Краткосрочный кеш (AVPlayer)**: для обычного просмотра, только в памяти
///
/// ⚠️ **Важно**: Краткосрочный кеш AVPlayer хранится только в оперативной памяти
/// и не сохраняется между запусками приложения. После перезапуска приложения
/// для просмотра видео не избранных жестов требуется активное интернет-соединение.
final class VideoCacheService: VideoCacheServiceProtocol {
    // MARK: - Singleton
    
    static let shared = VideoCacheService()
    
    // MARK: - Constants
    
    private enum Constants {
        /// Максимальный размер кеша на диске (500 MB)
        static let maxDiskCapacity: Int = 500 * 1024 * 1024
        /// Имя директории для кеша видео избранного
        static let cacheDirectoryName: String = "favorites_videos"
        /// Расширение файлов видео
        static let videoExtension: String = "mp4"
    }
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.videoCache", category: "VideoCacheService")
    
    /// Директория для хранения видео файлов
    private var cacheDirectory: URL?
    
    /// URLSession для загрузки видео
    private var downloadSession: URLSession?
    
    /// Очередь для thread-safe операций
    private let cacheQueue = DispatchQueue(label: "com.rsl.videoCacheService.queue")
    
    /// FileManager для работы с файлами
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    
    private init() {
        configureCacheDirectory()
        configureDownloadSession()
    }
    
    // MARK: - Configuration
    
    /// Настраивает директорию для кеша видео
    private func configureCacheDirectory() {
        cacheQueue.sync {
            guard let cachesDirectory = fileManager.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first else {
                logger.error("❌ Не удалось получить директорию Caches")
                return
            }
            
            let videoCacheDir = cachesDirectory.appendingPathComponent(Constants.cacheDirectoryName)
            
            // Создаем директорию если не существует
            if !fileManager.fileExists(atPath: videoCacheDir.path) {
                do {
                    try fileManager.createDirectory(
                        at: videoCacheDir,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    logger.info("✅ Директория кеша видео СОЗДАНА: \(videoCacheDir.path)")
                } catch {
                    logger.error("❌ Не удалось создать директорию кеша: \(error.localizedDescription)")
                    return
                }
            } else {
                // Директория уже существует - проверяем содержимое
                let files = (try? fileManager.contentsOfDirectory(atPath: videoCacheDir.path)) ?? []
                logger.info("📁 Директория кеша видео СУЩЕСТВУЕТ: \(videoCacheDir.path)")
                logger.info("📁 Файлов в кеше при запуске: \(files.count) - \(files)")
            }
            
            cacheDirectory = videoCacheDir
            logger.info("✅ Кеш видео настроен (макс: \(Constants.maxDiskCapacity / 1024 / 1024)MB)")
        }
    }
    
    /// Настраивает URLSession для загрузки видео
    private func configureDownloadSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        downloadSession = URLSession(configuration: configuration)
        logger.info("✅ URLSession для загрузки видео настроен")
    }
    
    // MARK: - File Path Helpers
    
    /// Возвращает путь к файлу видео в кеше
    /// - Parameter videoId: ID видео
    /// - Returns: URL файла или nil
    private func cacheFileURL(for videoId: String) -> URL? {
        guard let cacheDir = cacheDirectory else { return nil }
        return cacheDir.appendingPathComponent("\(videoId).\(Constants.videoExtension)")
    }
    
    /// Генерирует уникальный стабильный ID для видео из URL
    /// - Parameter url: URL видео
    /// - Returns: Уникальный ID (стабильный между запусками приложения)
    private func videoId(from url: URL) -> String {
        // Используем SHA256 для стабильного хеша (hashValue в Swift НЕ стабилен между запусками!)
        let data = Data(url.absoluteString.utf8)
        let hash = SHA256.hash(data: data)
        // Берём первые 16 символов hex-представления для краткости
        return hash.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Cache Size Management
    
    /// Возвращает текущий размер кеша на диске в байтах (thread-safe)
    /// - Returns: Размер в байтах
    func getCacheSize() -> Int {
        return cacheQueue.sync {
            return _getCacheSizeUnsafe()
        }
    }
    
    /// Внутренняя версия без синхронизации (вызывать только из cacheQueue!)
    private func _getCacheSizeUnsafe() -> Int {
        guard let cacheDir = cacheDirectory else { return 0 }
        
        do {
            let files = try fileManager.contentsOfDirectory(
                at: cacheDir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            var totalSize = 0
            for file in files {
                let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey])
                totalSize += resourceValues.fileSize ?? 0
            }
            return totalSize
        } catch {
            logger.error("❌ Ошибка подсчёта размера кеша: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Проверяет и поддерживает лимит размера кеша
    /// Удаляет старые файлы если размер превышает 500MB
    func ensureCacheLimit() {
        cacheQueue.async { [weak self] in
            guard let self = self,
                  let cacheDir = self.cacheDirectory else { return }
            
            // Используем unsafe версию, т.к. мы уже на cacheQueue
            let currentSize = self._getCacheSizeUnsafe()
            
            if currentSize > Constants.maxDiskCapacity {
                self.logger.warning("⚠️ Размер кеша (\(currentSize / 1024 / 1024)MB) превышает лимит, очистка старых файлов...")
                
                do {
                    // Получаем файлы отсортированные по дате модификации (старые первые)
                    let files = try self.fileManager.contentsOfDirectory(
                        at: cacheDir,
                        includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                        options: .skipsHiddenFiles
                    ).sorted { file1, file2 in
                        let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                        let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                        return date1 < date2
                    }
                    
                    var freedSize = 0
                    let targetSize = Constants.maxDiskCapacity * 80 / 100 // Освобождаем до 80% лимита
                    
                    for file in files {
                        if currentSize - freedSize <= targetSize {
                            break
                        }
                        
                        let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                        try self.fileManager.removeItem(at: file)
                        freedSize += fileSize
                        self.logger.info("🗑️ Удалён старый файл: \(file.lastPathComponent)")
                    }
                    
                    // Используем unsafe версию для логирования
                    let newSize = self._getCacheSizeUnsafe()
                    self.logger.info("✅ Очищено \(freedSize / 1024 / 1024)MB, новый размер: \(newSize / 1024 / 1024)MB")
                } catch {
                    self.logger.error("❌ Ошибка очистки кеша: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Cache Operations
    
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
        let id = videoId(from: url)
        guard let fileURL = cacheFileURL(for: id) else { return false }
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
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
        let id = videoId(from: originalURL)
        guard let fileURL = cacheFileURL(for: id) else {
            logger.warning("⚠️ Не удалось получить путь к файлу кеша для \(id)")
            return nil
        }
        
        let exists = fileManager.fileExists(atPath: fileURL.path)
        logger.info("🔍 Поиск видео в кеше: id=\(id), путь=\(fileURL.path), существует=\(exists)")
        
        guard exists else {
            // Проверим, есть ли вообще файлы в директории кеша
            if let cacheDir = cacheDirectory {
                let files = (try? fileManager.contentsOfDirectory(atPath: cacheDir.path)) ?? []
                logger.info("📁 Файлы в кеше: \(files)")
            }
            return nil
        }
        return fileURL
    }
    
    /// Очищает кеш для конкретного видео
    /// - Parameter video: Видео для удаления из кеша
    func clearCache(for video: SignVideo) {
        guard let url = URL(string: video.url) else { return }
        clearCache(for: url)
    }
    
    /// Очищает кеш по URL видео
    /// - Parameter url: URL видео
    func clearCache(for url: URL) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            let id = self.videoId(from: url)
            guard let fileURL = self.cacheFileURL(for: id) else { return }
            
            if self.fileManager.fileExists(atPath: fileURL.path) {
                do {
                    try self.fileManager.removeItem(at: fileURL)
                    self.logger.info("🗑️ Видео удалено из кеша: \(id)")
                } catch {
                    self.logger.error("❌ Ошибка удаления видео из кеша: \(error.localizedDescription)")
                }
            }
        }
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
        cacheQueue.async { [weak self] in
            guard let self = self,
                  let cacheDir = self.cacheDirectory else { return }
            
            do {
                let files = try self.fileManager.contentsOfDirectory(
                    at: cacheDir,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )
                
                for file in files {
                    try self.fileManager.removeItem(at: file)
                }
                
                self.logger.info("🗑️ Весь кеш видео очищен (\(files.count) файлов)")
            } catch {
                self.logger.error("❌ Ошибка очистки кеша: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Download & Cache
    
    /// Загружает видео и сохраняет в кеш
    /// - Parameter video: Видео для загрузки
    /// - Returns: URL локального файла
    /// - Throws: Ошибка при загрузке
    func downloadAndCache(video: SignVideo) async throws -> URL {
        guard let url = URL(string: video.url) else {
            throw VideoCacheError.invalidURL
        }
        return try await downloadAndCache(url: url)
    }
    
    /// Загружает видео по URL и сохраняет в кеш
    /// - Parameter url: URL видео
    /// - Returns: URL локального файла
    /// - Throws: Ошибка при загрузке
    func downloadAndCache(url: URL) async throws -> URL {
        let id = videoId(from: url)
        
        // Проверяем, есть ли уже в кеше
        if let cachedURL = getCachedVideoURL(originalURL: url) {
            logger.info("✅ Видео \(id) загружено из кеша")
            return cachedURL
        }
        
        guard let fileURL = cacheFileURL(for: id) else {
            throw VideoCacheError.cacheDirectoryNotAvailable
        }
        
        guard let session = downloadSession else {
            throw VideoCacheError.sessionNotConfigured
        }
        
        logger.info("📥 Загрузка видео \(id) с сервера в кеш...")
        
        do {
            let (tempURL, response) = try await session.download(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw VideoCacheError.downloadFailed
            }
            
            // Перемещаем временный файл в кеш
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            try fileManager.moveItem(at: tempURL, to: fileURL)
            
            // Получаем размер файла
            let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            logger.info("✅ Видео \(id) сохранено в кеш (\(fileSize / 1024)KB)")
            
            // Проверяем лимит кеша
            ensureCacheLimit()
            
            return fileURL
        } catch {
            logger.error("❌ Ошибка загрузки видео \(id): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Предзагружает видео в кеш (асинхронно, без ожидания)
    /// - Parameter video: Видео для предзагрузки
    func preloadVideo(_ video: SignVideo) async {
        do {
            _ = try await downloadAndCache(video: video)
        } catch {
            logger.warning("⚠️ Не удалось предзагрузить видео: \(error.localizedDescription)")
        }
    }
    
    /// Предзагружает все видео жеста
    /// - Parameter videos: Массив видео
    func preloadVideos(_ videos: [SignVideo]) async {
        for video in videos {
            await preloadVideo(video)
        }
    }
}
