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
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        let jsonData = try encoder.encode(data)
        
        guard let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw CacheError.unableToAccessDocumentsDirectory
        }
        
        let fileURL = documentsURL.appendingPathComponent("\(cacheKey).json")
        
        do {
            try jsonData.write(to: fileURL, options: .atomic)
            logger.info("✅ Данные сохранены в кеш (\(data.signs.count) жестов, \(data.categories.count) категорий)")
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
            return nil
        }
        
        let fileURL = documentsURL.appendingPathComponent("\(cacheKey).json")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            logger.debug("ℹ️ Кеш не найден")
            return nil
        }
        
        do {
            let jsonData = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let data = try decoder.decode(SyncData.self, from: jsonData)
            logger.info("✅ Данные загружены из кеша (\(data.signs.count) жестов, \(data.categories.count) категорий)")
            return data
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

/// Ошибки кеширования
enum CacheError: LocalizedError {
    case unableToAccessDocumentsDirectory
    case unableToSave(Error)
    case unableToLoad(Error)
    
    var errorDescription: String? {
        switch self {
        case .unableToAccessDocumentsDirectory:
            return "Не удалось получить доступ к директории документов"
        case .unableToSave(let error):
            return "Ошибка сохранения кеша: \(error.localizedDescription)"
        case .unableToLoad(let error):
            return "Ошибка загрузки кеша: \(error.localizedDescription)"
        }
    }
}
