import Foundation
import os.log

/// Сервис для управления локальным кешем данных синхронизации
final class CacheService {
    private let logger = Logger(subsystem: "com.rsl.CacheService", category: "cache")
    // MARK: - Properties
    
    private let cacheKey = "cached_signs_data"
    private let fileManager = FileManager.default
    
    // MARK: - Methods
    
    /// Сохраняет данные синхронизации в локальный кеш
    /// - Parameter data: Данные для сохранения
    /// - Throws: Ошибка при сохранении
    func save(_ data: SyncData) throws {
        logger.info("💾 Сохранение в кеш: \(data.signs.count) жестов, \(data.categories.count) категорий")
        
        let encoder = JSONEncoder()
        // Unix timestamp для совместимости с Raw API
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        let jsonData = try encoder.encode(data)
        logger.info("💾 Размер данных для сохранения: \(jsonData.count) байт")
        
        guard let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            logger.error("❌ Не удалось получить Documents директорию для сохранения")
            throw CacheError.unableToAccessDocumentsDirectory
        }
        
        let fileURL = documentsURL.appendingPathComponent("\(cacheKey).json")
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
        guard let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            logger.error("❌ Не удалось получить Documents директорию")
            return nil
        }
        
        let fileURL = documentsURL.appendingPathComponent("\(cacheKey).json")
        
        logger.info("📁 Путь к кешу: \(fileURL.path)")
        logger.info("📁 Файл существует: \(self.fileManager.fileExists(atPath: fileURL.path))")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            logger.info("ℹ️ Файл кеша не найден")
            return nil
        }
        
        do {
            let jsonData = try Data(contentsOf: fileURL)
            logger.info("📄 Размер файла кеша: \(jsonData.count) байт")
            
            // Сначала пробуем новый формат (Unix timestamp)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let data = try decoder.decode(SyncData.self, from: jsonData)
                logger.info("✅ Данные загружены из кеша (новый формат, \(data.signs.count) жестов, \(data.categories.count) категорий)")
                return data
            } catch {
                // Fallback: пробуем старый формат (ISO 8601) для обратной совместимости
                logger.info("ℹ️ Попытка загрузки кеша в старом формате (ISO 8601)...")
                let legacyDecoder = JSONDecoder()
                legacyDecoder.dateDecodingStrategy = .iso8601
                legacyDecoder.keyDecodingStrategy = .convertFromSnakeCase
                
                let data = try legacyDecoder.decode(SyncData.self, from: jsonData)
                logger.info("✅ Данные загружены из кеша (legacy формат, \(data.signs.count) жестов, \(data.categories.count) категорий)")
                
                // Пересохраняем в новом формате для будущих загрузок
                logger.info("🔄 Миграция кеша на новый формат...")
                try? save(data)
                
                return data
            }
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
        guard let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return false
        }
        
        let fileURL = documentsURL.appendingPathComponent("\(cacheKey).json")
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Удаляет кеш
    /// - Throws: Ошибка при удалении
    func clearCache() throws {
        guard let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return
        }
        
        let fileURL = documentsURL.appendingPathComponent("\(cacheKey).json")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
            logger.info("✅ Кеш удалён")
        }
    }
}
