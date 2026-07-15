import Foundation
import os.log

/// Управляет кешированием ETag для условных HTTP-запросов
/// Согласно RFC 7232, ETag используется для оптимизации сетевого трафика
final class ETagManager: Sendable {
    // MARK: - Constants
    
    /// Длина MD5 хеша в hex формате (32 символа)
    private static let expectedETagLength = 32
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.ETagManager", category: "etag")
    /// `UserDefaults` is documented by Apple as thread-safe; not `Sendable`-annotated in Foundation.
    private nonisolated(unsafe) let userDefaults: UserDefaults
    
    /// Ключи для хранения ETag
    enum StorageKey: String {
        case syncData = "sync_data_etag"
        case syncCheck = "sync_check_etag"
    }
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Public Methods
    
    /// Получает сохранённый ETag
    /// - Parameter key: Ключ для получения ETag
    /// - Returns: Нормализованный ETag или nil
    func getETag(for key: StorageKey) -> String? {
        userDefaults.string(forKey: key.rawValue)
    }
    
    /// Сохраняет ETag после нормализации
    /// - Parameters:
    ///   - etag: Сырой ETag из HTTP заголовка
    ///   - key: Ключ для сохранения
    /// - Returns: true если ETag был сохранён, false если отклонён
    @discardableResult
    func saveETag(_ etag: String, for key: StorageKey) -> Bool {
        let normalized = normalizeETag(etag)
        
        guard isValidETag(normalized, rawValue: etag) else {
            return false
        }
        
        userDefaults.set(normalized, forKey: key.rawValue)
        logSaveSuccess(normalized: normalized, raw: etag, key: key)
        return true
    }
    
    /// Удаляет сохранённый ETag
    /// - Parameter key: Ключ для удаления
    func removeETag(for key: StorageKey) {
        userDefaults.removeObject(forKey: key.rawValue)
        logger.debug("🗑️ Удалён ETag для \(key.rawValue)")
    }
    
    /// Нормализует ETag: убирает кавычки и суффиксы
    /// Согласно MOBILE_APP_INTEGRATION.md:
    /// - MD5 хеш: 32 символа (hex)
    /// - Суффиксы могут быть добавлены сервером/прокси (:gzip, :deflate)
    func normalizeETag(_ etag: String) -> String {
        var cleaned = etag
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
        
        // Берём только часть до двоеточия (основной ETag)
        if let colonIndex = cleaned.firstIndex(of: ":") {
            cleaned = String(cleaned[..<colonIndex])
        }
        
        return cleaned
    }
    
    // MARK: - Private Methods
    
    private func isValidETag(_ normalized: String, rawValue: String) -> Bool {
        guard normalized.count == Self.expectedETagLength else {
            logInvalidETag(normalized: normalized, raw: rawValue)
            return false
        }
        return true
    }
    
    private func logInvalidETag(normalized: String, raw: String) {
        logger.error("❌ НЕ СОХРАНЯЕМ неполный ETag: длина=\(normalized.count) (ожидается \(Self.expectedETagLength))")
        logger.error("   Нормализованный: \(normalized)")
        logger.error("   Исходный: \(raw)")
        logger.error("   💡 Это означает проблему на сервере или в сети — ETag был обрезан")
    }
    
    private func logSaveSuccess(normalized: String, raw: String, key: StorageKey) {
        if normalized != raw {
            logger.debug("💾 Сохранён ETag для \(key.rawValue): \(normalized) (исходный: \(raw))")
        } else {
            logger.debug("💾 Сохранён ETag для \(key.rawValue): \(normalized)")
        }
    }
}

