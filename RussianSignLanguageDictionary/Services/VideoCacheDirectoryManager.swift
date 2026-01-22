import Foundation
import os.log
import CryptoKit

/// Менеджер для работы с директорией кеша видео
final class VideoCacheDirectoryManager {
    // MARK: - Constants
    
    private enum Constants {
        /// Максимальный размер кеша на диске (500 MB)
        static let maxDiskCapacity: Int = 500 * 1024 * 1024
        /// Имя директории для кеша видео избранного
        static let cacheDirectoryName: String = "favorites_videos"
        /// Расширение файлов видео
        static let videoExtension: String = "mp4"
        /// Целевой размер после очистки (80% от лимита)
        static let targetSizePercent: Int = 80
    }
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.videoCache", category: "DirectoryManager")
    
    /// Директория для хранения видео файлов
    private(set) var cacheDirectory: URL?
    
    /// Очередь для thread-safe операций
    private let cacheQueue = DispatchQueue(label: "com.rsl.videoCacheDirectory.queue")
    
    /// FileManager для работы с файлами
    private let fileManager: FileManager
    
    /// Максимальный размер кеша
    let maxDiskCapacity: Int
    
    // MARK: - Initialization
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.maxDiskCapacity = Constants.maxDiskCapacity
        configureCacheDirectory()
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
                let files = (try? fileManager.contentsOfDirectory(atPath: videoCacheDir.path)) ?? []
                logger.info("📁 Директория кеша видео СУЩЕСТВУЕТ: \(videoCacheDir.path)")
                logger.info("📁 Файлов в кеше при запуске: \(files.count)")
            }
            
            cacheDirectory = videoCacheDir
            logger.info("✅ Кеш видео настроен (макс: \(Constants.maxDiskCapacity / 1024 / 1024)MB)")
        }
    }
    
    // MARK: - File Path Helpers
    
    /// Возвращает путь к файлу видео в кеше
    /// - Parameter videoId: ID видео
    /// - Returns: URL файла или nil
    func cacheFileURL(for videoId: String) -> URL? {
        guard let cacheDir = cacheDirectory else { return nil }
        return cacheDir.appendingPathComponent("\(videoId).\(Constants.videoExtension)")
    }
    
    /// Генерирует уникальный стабильный ID для видео из URL
    /// - Parameter url: URL видео
    /// - Returns: Уникальный ID (стабильный между запусками приложения)
    func videoId(from url: URL) -> String {
        // Используем SHA256 для стабильного хеша (hashValue в Swift НЕ стабилен между запусками!)
        let data = Data(url.absoluteString.utf8)
        let hash = SHA256.hash(data: data)
        // Берём первые 16 символов hex-представления для краткости
        return hash.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - File Existence Check
    
    /// Проверяет существование файла в кеше
    /// - Parameter fileURL: URL файла
    /// - Returns: true если файл существует
    func fileExists(at fileURL: URL) -> Bool {
        fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Проверяет существование файла по пути
    /// - Parameter path: Путь к файлу
    /// - Returns: true если файл существует
    func fileExists(atPath path: String) -> Bool {
        fileManager.fileExists(atPath: path)
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
    /// Удаляет старые файлы если размер превышает лимит
    func ensureCacheLimit() {
        cacheQueue.async { [weak self] in
            guard let self = self,
                  let cacheDir = self.cacheDirectory else { return }
            
            let currentSize = self._getCacheSizeUnsafe()
            
            guard currentSize > Constants.maxDiskCapacity else { return }
            
            self.logger.warning("⚠️ Размер кеша (\(currentSize / 1024 / 1024)MB) превышает лимит, очистка...")
            
            do {
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
                let targetSize = Constants.maxDiskCapacity * Constants.targetSizePercent / 100
                
                for file in files {
                    if currentSize - freedSize <= targetSize {
                        break
                    }
                    
                    let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    try self.fileManager.removeItem(at: file)
                    freedSize += fileSize
                    self.logger.info("🗑️ Удалён старый файл: \(file.lastPathComponent)")
                }
                
                let newSize = self._getCacheSizeUnsafe()
                self.logger.info("✅ Очищено \(freedSize / 1024 / 1024)MB, новый размер: \(newSize / 1024 / 1024)MB")
            } catch {
                self.logger.error("❌ Ошибка очистки кеша: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - File Operations
    
    /// Удаляет файл из кеша
    /// - Parameter url: URL видео
    func removeFile(for url: URL) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            let id = self.videoId(from: url)
            guard let fileURL = self.cacheFileURL(for: id) else { return }
            
            guard self.fileManager.fileExists(atPath: fileURL.path) else { return }
            
            do {
                try self.fileManager.removeItem(at: fileURL)
                self.logger.info("🗑️ Видео удалено из кеша: \(id)")
            } catch {
                self.logger.error("❌ Ошибка удаления видео из кеша: \(error.localizedDescription)")
            }
        }
    }
    
    /// Удаляет файл по URL
    /// - Parameter fileURL: URL файла для удаления
    func removeItem(at fileURL: URL) throws {
        try fileManager.removeItem(at: fileURL)
    }
    
    /// Перемещает файл
    /// - Parameters:
    ///   - srcURL: Исходный URL
    ///   - dstURL: Целевой URL
    func moveItem(from srcURL: URL, to dstURL: URL) throws {
        if fileManager.fileExists(atPath: dstURL.path) {
            try fileManager.removeItem(at: dstURL)
        }
        try fileManager.moveItem(at: srcURL, to: dstURL)
    }
    
    /// Очищает весь кеш
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
    
    /// Возвращает список файлов в кеше
    func listCachedFiles() -> [String] {
        guard let cacheDir = cacheDirectory else { return [] }
        return (try? fileManager.contentsOfDirectory(atPath: cacheDir.path)) ?? []
    }
}
