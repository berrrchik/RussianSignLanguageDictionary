import Foundation
import os.log

/// Декоратор для логирования операций синхронизации
/// Следует паттерну Decorator для разделения ответственностей:
/// - SyncRepository отвечает за сетевые запросы
/// - LoggingSyncRepositoryDecorator отвечает за логирование
final class LoggingSyncRepositoryDecorator: SyncRepositoryProtocol {
    // MARK: - Properties
    
    private let wrapped: SyncRepositoryProtocol
    private let logger = Logger(subsystem: "com.rsl.SyncRepository", category: "sync")
    
    // MARK: - Initialization
    
    init(wrapped: SyncRepositoryProtocol) {
        self.wrapped = wrapped
    }
    
    // MARK: - SyncRepositoryProtocol
    
    func checkForUpdates(lastUpdated: Date?) async throws -> SyncMetadata {
        logCheckUpdatesStart(lastUpdated: lastUpdated)
        
        do {
            let result = try await wrapped.checkForUpdates(lastUpdated: lastUpdated)
            logCheckUpdatesSuccess(result: result)
            return result
        } catch {
            logError(error, context: "checkForUpdates")
            throw error
        }
    }
    
    func fetchAllData(cachedDataProvider: @escaping () throws -> SyncData) async throws -> SyncData {
        logger.info("📥 Начало загрузки данных...")
        
        do {
            let result = try await wrapped.fetchAllData(cachedDataProvider: cachedDataProvider)
            logFetchDataSuccess(result: result)
            return result
        } catch {
            logError(error, context: "fetchAllData")
            throw error
        }
    }
    
    // MARK: - Private Logging Methods
    
    private func logCheckUpdatesStart(lastUpdated: Date?) {
        if let lastUpdated = lastUpdated {
            let formatter = ISO8601DateFormatter()
            logger.info("🔄 Проверка обновлений с \(formatter.string(from: lastUpdated), privacy: .public)")
        } else {
            logger.info("🔄 Проверка обновлений (первый запрос)")
        }
    }
    
    private func logCheckUpdatesSuccess(result: SyncMetadata) {
        if result.hasUpdates {
            logger.info("✅ Обнаружены обновления")
        } else {
            logger.info("✅ Обновлений нет (данные актуальны)")
        }
    }
    
    private func logFetchDataSuccess(result: SyncData) {
        logger.info("✅ Загружено: \(result.signs.count) жестов, \(result.categories.count) категорий, \(result.lessons.count) уроков")
    }
    
    private func logError(_ error: Error, context: String) {
        if let syncError = error as? SyncError {
            logSyncError(syncError, context: context)
        } else {
            logger.error("❌ [\(context, privacy: .public)] Ошибка: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func logSyncError(_ error: SyncError, context: String) {
        switch error {
        case .noInternet:
            logger.warning("⚠️ [\(context, privacy: .public)] Нет подключения к интернету")
        case .serverUnavailable:
            logger.warning("⚠️ [\(context, privacy: .public)] Сервер недоступен")
        case .serverError(let code):
            logger.error("❌ [\(context, privacy: .public)] Ошибка сервера: \(code)")
        case .decodingError(let underlying):
            logger.error("❌ [\(context, privacy: .public)] Ошибка декодирования: \(underlying.localizedDescription, privacy: .public)")
        case .invalidResponse:
            logger.error("❌ [\(context, privacy: .public)] Неверный ответ сервера")
        case .networkError(let underlying):
            logger.error("❌ [\(context, privacy: .public)] Сетевая ошибка: \(underlying.localizedDescription, privacy: .public)")
        }
    }
}
