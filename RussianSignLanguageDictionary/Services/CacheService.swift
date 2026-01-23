import Foundation
import os.log

/// Сервис для управления локальным кешем данных синхронизации
final class CacheService {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.CacheService", category: "cache")
    private let cacheKey = "cached_signs_data"
    private let fileManager: FileManager
    
    // MARK: - Initialization
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    // MARK: - Public Methods
    
    /// Сохраняет данные синхронизации в локальный кеш
    /// - Parameter data: Данные для сохранения
    /// - Throws: Ошибка при сохранении
    func save(_ data: SyncData) throws {
        logger.info("💾 Сохранение в кеш: \(data.signs.count) жестов, \(data.categories.count) категорий")
        
        let jsonData = try APIJSONEncoder.shared.encode(data)
        logger.info("💾 Размер данных для сохранения: \(jsonData.count) байт")
        
        let fileURL = try cacheFileURL()
        logger.info("💾 Путь для сохранения: \(fileURL.path)")
        
        do {
            try jsonData.write(to: fileURL, options: .atomic)
            let savedExists = fileManager.fileExists(atPath: fileURL.path)
            logger.info("✅ Данные сохранены в кеш. Файл существует: \(savedExists)")
        } catch {
            logger.error("❌ Ошибка сохранения в кеш: \(error.localizedDescription)")
            throw CacheError.unableToSave(error)
        }
    }
    
    /// Загружает данные из локального кеша
    /// - Returns: Кешированные данные или nil, если кеш отсутствует
    /// - Throws: Ошибка при загрузке
    func load() throws -> SyncData? {
        let fileURL: URL
        do {
            fileURL = try cacheFileURL()
        } catch {
            logger.error("❌ Не удалось получить Documents директорию")
            return nil
        }
        
        logger.debug("📁 Путь к кешу: \(fileURL.path)")
        logger.debug("📁 Файл существует: \(self.fileManager.fileExists(atPath: fileURL.path))")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            logger.info("ℹ️ Файл кеша не найден")
            return nil
        }
        
        do {
            let jsonData = try Data(contentsOf: fileURL)
            logger.debug("📄 Размер файла кеша: \(jsonData.count) байт")
            
            let data = try APIJSONDecoder.shared.decode(SyncData.self, from: jsonData)
            return data
        } catch let decodingError as DecodingError {
            logger.error("❌ Ошибка декодирования кеша: \(String(describing: decodingError))")
            throw CacheError.unableToLoad(decodingError)
        } catch {
            logger.error("❌ Ошибка загрузки из кеша: \(error.localizedDescription)")
            throw CacheError.unableToLoad(error)
        }
    }
    
    /// Проверяет наличие кеша
    /// - Returns: true, если кеш существует
    func hasCache() -> Bool {
        guard let fileURL = try? cacheFileURL() else {
            return false
        }
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Удаляет кеш
    /// - Throws: Ошибка при удалении
    func clearCache() throws {
        guard let fileURL = try? cacheFileURL() else {
            return
        }
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
            logger.info("✅ Кеш удалён")
        }
    }
    
    // MARK: - Private Methods
    
    private func cacheFileURL() throws -> URL {
        guard let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw CacheError.unableToAccessDocumentsDirectory
        }
        
        return documentsURL.appendingPathComponent("\(cacheKey).json")
    }
}
