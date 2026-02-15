import Foundation
import SwiftUI
import os.log

/// ViewModel для управления синхронизацией данных
@MainActor
final class SyncViewModel: ObservableObject {
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.rsl.sync", category: "SyncViewModel")
    // MARK: - Published Properties
    
    /// Флаг выполнения синхронизации
    @Published var isSyncing = false
    
    /// Дата последней синхронизации
    @Published var lastSyncDate: Date?
    
    /// Ошибка синхронизации (если есть)
    @Published var syncError: String?
    
    // MARK: - Private Properties
    
    private let syncRepository: SyncRepositoryProtocol
    private let cacheService: CacheService
    private let networkMonitor: NetworkMonitorProtocol
    
    // MARK: - Initialization
    
    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            syncRepository: container.resolve(SyncRepositoryProtocol.self),
            cacheService: container.resolve(CacheService.self),
            networkMonitor: container.resolve(NetworkMonitorProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(
        syncRepository: SyncRepositoryProtocol,
        cacheService: CacheService,
        networkMonitor: NetworkMonitorProtocol
    ) {
        self.syncRepository = syncRepository
        self.cacheService = cacheService
        self.networkMonitor = networkMonitor
        
        // Загружаем дату последней синхронизации из кеша
        loadLastSyncDate()
    }
    
    // MARK: - Methods
    
    /// Выполняет синхронизацию данных
    /// 
    /// **Важно**: Сначала проверяет наличие интернета.
    /// Если интернета нет - НЕ показывает overlay синхронизации,
    /// приложение работает на кешированных данных.
    func sync() async {
        // СНАЧАЛА проверяем интернет, чтобы не показывать overlay зря
        let isConnected = await networkMonitor.checkConnection()
        
        if !isConnected {
            logger.info("⚠️ Нет подключения к интернету, синхронизация пропущена")
            return
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            let metadata = try await syncRepository.checkForUpdates(lastUpdated: lastSyncDate)
            
            if metadata.hasUpdates {
                logger.info("🔄 Обнаружены обновления, загрузка данных...")
                
                let data = try await syncRepository.fetchAllData(
                    cachedDataProvider: { [weak self] in
                        guard let self = self else {
                            throw SyncError.networkError(
                                NSError(domain: "SyncViewModel", code: -1, userInfo: [
                                    NSLocalizedDescriptionKey: "SyncViewModel deallocated"
                                ])
                            )
                        }
                        
                        guard let cached = try self.cacheService.load() else {
                            throw SyncError.networkError(
                                NSError(domain: "SyncViewModel", code: -1, userInfo: [
                                    NSLocalizedDescriptionKey: "Cache unavailable for 304"
                                ])
                            )
                        }
                        return cached
                    }
                )
                
                try cacheService.save(data)
                
                lastSyncDate = data.lastUpdated
                saveLastSyncDate(data.lastUpdated)
                
                logger.info("✅ Синхронизация завершена успешно")
            } else {
                logger.info("ℹ️ Обновлений нет")
            }
        } catch let error as SyncError {
            handleSyncError(error)
        } catch {
            logger.error("❌ Неизвестная ошибка синхронизации: \(error.localizedDescription)")
            syncError = "Ошибка синхронизации: \(error.localizedDescription)"
        }
        
        isSyncing = false
    }
    
    /// Обрабатывает ошибки синхронизации
    private func handleSyncError(_ error: SyncError) {
        switch error {
        case .noInternet:
            logger.info("⚠️ Нет подключения к интернету, используются кешированные данные")
            syncError = nil
            
        case .serverUnavailable:
            logger.info("⚠️ Сервер недоступен, используются кешированные данные")
            syncError = nil
            
        case .networkError:
            logger.info("⚠️ Ошибка сети, используются кешированные данные")
            syncError = nil
            
        default:
            syncError = ErrorMessageMapper.message(for: error)
        }
    }
    
    /// Загружает дату последней синхронизации из UserDefaults
    private func loadLastSyncDate() {
        if let timestamp = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = timestamp
        }
    }
    
    /// Сохраняет дату последней синхронизации в UserDefaults
    private func saveLastSyncDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "lastSyncDate")
    }
    
    /// Очищает ошибку синхронизации
    func clearError() {
        syncError = nil
    }
}
