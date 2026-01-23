import Foundation
import os.log

/// Загрузчик видео для кеша
///
/// Отвечает за:
/// - Загрузку видео с сервера
/// - Сохранение в файловый кеш
final class VideoCacheDownloader {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.videoCache", category: "Downloader")
    
    /// URLSession для загрузки видео
    private let downloadSession: URLSession
    
    /// Менеджер директории кеша
    private let directoryManager: VideoCacheDirectoryManager
    
    // MARK: - Initialization
    
    init(
        directoryManager: VideoCacheDirectoryManager,
        session: URLSession? = nil
    ) {
        self.directoryManager = directoryManager
        self.downloadSession = session ?? Self.createDefaultSession()
        logger.info("✅ VideoCacheDownloader инициализирован")
    }
    
    // MARK: - Download
    
    /// Загружает видео по URL и сохраняет в кеш
    /// - Parameter url: URL видео
    /// - Returns: URL локального файла
    /// - Throws: Ошибка при загрузке
    func downloadAndCache(url: URL) async throws -> URL {
        let id = directoryManager.videoId(from: url)
        
        // Проверяем, есть ли уже в кеше
        if let cachedURL = getCachedVideoURL(originalURL: url) {
            logger.info("✅ Видео \(id) загружено из кеша")
            return cachedURL
        }
        
        guard let fileURL = directoryManager.cacheFileURL(for: id) else {
            throw VideoCacheError.cacheDirectoryNotAvailable
        }
        
        logger.info("📥 Загрузка видео \(id) с сервера в кеш...")
        
        let (tempURL, response) = try await downloadSession.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoCacheError.downloadFailed
        }
        
        // Перемещаем временный файл в кеш
        try directoryManager.moveItem(from: tempURL, to: fileURL)
        
        // Получаем размер файла для логирования
        let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        logger.info("✅ Видео \(id) сохранено в кеш (\(fileSize / 1024)KB)")
        
        // Проверяем лимит кеша
        directoryManager.ensureCacheLimit()
        
        return fileURL
    }
    
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
    
    // MARK: - Cache Check
    
    /// Возвращает URL кешированного видео файла по оригинальному URL
    /// - Parameter originalURL: Оригинальный URL видео
    /// - Returns: URL файла или nil если не кеширован
    func getCachedVideoURL(originalURL: URL) -> URL? {
        let id = directoryManager.videoId(from: originalURL)
        guard let fileURL = directoryManager.cacheFileURL(for: id) else {
            logger.warning("⚠️ Не удалось получить путь к файлу кеша для \(id)")
            return nil
        }
        
        let exists = directoryManager.fileExists(at: fileURL)
        logger.info("🔍 Поиск видео в кеше: id=\(id), существует=\(exists)")
        
        guard exists else {
            let files = directoryManager.listCachedFiles()
            logger.info("📁 Файлы в кеше: \(files)")
            return nil
        }
        return fileURL
    }
    
    // MARK: - Preload
    
    /// Предзагружает видео в кеш (асинхронно, без ожидания)
    /// - Parameter video: Видео для предзагрузки
    func preloadVideo(_ video: SignVideo) async {
        do {
            _ = try await downloadAndCache(video: video)
        } catch {
            logger.warning("⚠️ Не удалось предзагрузить видео: \(error.localizedDescription)")
        }
    }
    
    /// Предзагружает все видео
    /// - Parameter videos: Массив видео
    func preloadVideos(_ videos: [SignVideo]) async {
        for video in videos {
            await preloadVideo(video)
        }
    }
    
    // MARK: - Session Configuration
    
    private static func createDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        return URLSession(configuration: configuration)
    }
}
