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

    /// Статус стартовой инициализации приложения
    @Published private(set) var startupStatus: AppStartupStatus = .idle
    
    // MARK: - Private Properties
    
    private let syncRepository: SyncRepositoryProtocol
    private let signRepository: SignRepositoryProtocol
    private let cacheService: CacheService
    private let networkMonitor: NetworkMonitorProtocol
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    
    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            syncRepository: container.resolve(SyncRepositoryProtocol.self),
            signRepository: container.resolve(SignRepositoryProtocol.self),
            cacheService: container.resolve(CacheService.self),
            networkMonitor: container.resolve(NetworkMonitorProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(
        syncRepository: SyncRepositoryProtocol,
        signRepository: SignRepositoryProtocol,
        cacheService: CacheService,
        networkMonitor: NetworkMonitorProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.syncRepository = syncRepository
        self.signRepository = signRepository
        self.cacheService = cacheService
        self.networkMonitor = networkMonitor
        self.userDefaults = userDefaults
        
        // Загружаем дату последней синхронизации из кеша
        loadLastSyncDate()
    }
    
    // MARK: - Methods

    func initializeApp(force: Bool = false) async {
        if !force {
            switch startupStatus {
            case .loading, .ready, .readyUsingCachedData:
                return
            case .idle, .blocked:
                break
            }
        }

        startupStatus = .loading

        do {
            _ = try await signRepository.loadAllSigns()
            startupStatus = startupStatus(for: signRepository.currentDataStatus)
        } catch {
            startupStatus = blockingStartupStatus(for: error)
        }
    }
    
    /// Выполняет синхронизацию данных
    /// 
    /// **Важно**: Сначала проверяет наличие интернета.
    /// Если интернета нет - НЕ показывает overlay синхронизации,
    /// приложение работает на кешированных данных.
    func sync() async {
        guard !isSyncing else {
            logger.info("ℹ️ Синхронизация уже выполняется, повторный запуск пропущен")
            return
        }

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
                
                // Логируем успешную синхронизацию в аналитику
                AnalyticsService.logSyncCompleted(
                    signsCount: data.signs.count,
                    categoriesCount: data.categories.count,
                    lessonsCount: data.lessons.count
                )
            } else {
                logger.info("ℹ️ Обновлений нет")
            }
        } catch let error as SyncError {
            handleSyncError(error)
            CrashlyticsErrorReporter.capture(error, context: ["operation": "sync"], subsystem: "com.rsl.sync")
            
            // Логируем ошибку синхронизации в аналитику
            if syncError != nil {
                AnalyticsService.logSyncFailed(errorType: String(describing: error))
            }
        } catch {
            logger.error("❌ Неизвестная ошибка синхронизации: \(error.localizedDescription)")
            syncError = "Ошибка синхронизации: \(error.localizedDescription)"
            CrashlyticsErrorReporter.capture(error, context: ["operation": "sync"], subsystem: "com.rsl.sync")
            AnalyticsService.logSyncFailed(errorType: String(describing: type(of: error)))
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
        if let timestamp = userDefaults.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = timestamp
        }
    }
    
    /// Сохраняет дату последней синхронизации в UserDefaults
    private func saveLastSyncDate(_ date: Date) {
        userDefaults.set(date, forKey: "lastSyncDate")
    }
    
    /// Очищает ошибку синхронизации
    func clearError() {
        syncError = nil
    }

    private func startupStatus(for dataStatus: RepositoryDataStatus) -> AppStartupStatus {
        switch dataStatus {
        case .availableLocally, .usingCachedData:
            return .readyUsingCachedData
        case .noData(let reason):
            return .blocked(reason)
        case .idle, .loading, .updated, .upToDate:
            return .ready
        }
    }

    private func blockingStartupStatus(for error: Error) -> AppStartupStatus {
        if case .noData(let reason) = signRepository.currentDataStatus {
            return .blocked(reason)
        }

        if let syncError = error as? SyncError {
            switch syncError {
            case .noInternet:
                return .blocked(.noInternet)
            case .serverUnavailable, .serverError, .networkError, .decodingError, .invalidResponse:
                return .blocked(.serverUnavailable)
            }
        }

        return awaitNoInternetFallback()
    }

    private func awaitNoInternetFallback() -> AppStartupStatus {
        networkMonitor.isConnected() ? .blocked(.serverUnavailable) : .blocked(.noInternet)
    }
}
