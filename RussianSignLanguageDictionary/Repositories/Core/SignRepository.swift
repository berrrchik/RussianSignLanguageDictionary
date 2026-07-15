import Foundation
import os.log
import Combine
import FirebasePerformance

/// Репозиторий для работы с данными о жестах
///
/// **Performance Monitoring**: Загрузка и парсинг данных отслеживаются через Firebase Performance Monitoring:
/// - `signs_data_load` - загрузка данных жестов (из кеша или с сервера)
nonisolated final class SignRepository: SignRepositoryProtocol, @unchecked Sendable {

    // MARK: - Properties

    let logger = Logger(subsystem: "com.rsl.SignRepository", category: "repository")

    let syncRepository: SyncRepositoryProtocol
    private let cacheService: CacheServiceProtocol
    let networkMonitor: NetworkMonitorProtocol

    let memoryCache = MemoryCacheManager<SyncData>(label: "com.rsl.signRepository.memoryCache")
    private let loadCoordinator = DataLoadCoordinator<SyncData>(
        subsystem: "com.rsl.SignRepository",
        category: "LoadCoordinator"
    )
    private let dataStatusSubject = CurrentValueSubject<RepositoryDataStatus, Never>(.idle)

    let backgroundSyncCoordinator = SignRepositoryBackgroundSyncCoordinator(
        subsystem: "com.rsl.SignRepository",
        category: "BackgroundSync"
    )

    /// Защита от гонки check-then-send в `updateDataStatus` между foreground `loadAllSigns()`
    /// и фоновой синхронизацией.
    private let dataStatusLock = NSLock()

    // MARK: - Publishers
    
    let dataUpdatedSubject = PassthroughSubject<SyncData, Never>()
    var dataUpdatedPublisher: AnyPublisher<SyncData, Never> {
        dataUpdatedSubject.eraseToAnyPublisher()
    }

    var dataStatusPublisher: AnyPublisher<RepositoryDataStatus, Never> {
        dataStatusSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var currentDataStatus: RepositoryDataStatus {
        dataStatusSubject.value
    }
    
    // MARK: - Initialization
    
    init(
        syncRepository: SyncRepositoryProtocol,
        cacheService: CacheServiceProtocol,
        networkMonitor: NetworkMonitorProtocol = NetworkMonitor()
    ) {
        self.syncRepository = syncRepository
        self.cacheService = cacheService
        self.networkMonitor = networkMonitor
    }
    
    // MARK: - SignRepositoryProtocol
    
    func loadAllSigns() async throws -> [Sign] {
        let syncData = try await loadDataWithSync()
        return syncData.signs
    }
    
    func loadCategories() async throws -> [Category] {
        let syncData = try await loadDataWithSync()
        return syncData.categories.sorted { $0.order < $1.order }
    }
    
    func getSign(byId id: String) async throws -> Sign? {
        let signs = try await loadAllSigns()
        return signs.first { $0.id == id }
    }
    
    func getSigns(byCategory categoryId: String) async throws -> [Sign] {
        let signs = try await loadAllSigns()
        return signs.filter { $0.categoryId == categoryId }
    }
    
    func searchSigns(query: String) async throws -> [Sign] {
        guard !query.isEmpty else { return [] }
        
        let signs = try await loadAllSigns()
        return SignTextSearchHelper.filterSigns(signs, query: query, includeDescription: true)
    }

    func cachedSigns() -> [Sign]? {
        memoryCache.get()?.signs
    }

    func cachedData() -> SyncData? {
        memoryCache.get()
    }
    
    // MARK: - Data Loading
    
    private func loadDataWithSync() async throws -> SyncData {
        if let cached = memoryCache.get() {
            logger.debug("📦 Данные из memory cache (быстрый путь)")
            updateDataStatus(.availableLocally(.memoryCache))
            await scheduleBackgroundSyncIfNeeded()
            return cached
        }
        
        logger.info("🔄 Начало загрузки данных (memory cache пуст)")
        return try await loadCoordinator.getOrCreateTask { [weak self] in
            guard let self else { throw SignRepositoryError.noDataAvailable }
            return try await self.performDataLoad()
        }
    }
    
    private func performDataLoad() async throws -> SyncData {
        let trace = PerformanceService.startTrace("signs_data_load")
        defer { PerformanceService.stopTrace(trace) }
        updateDataStatus(.loading)
        
        logger.info("🔍 Проверка локального кеша...")
        
        // Попытка загрузить из дискового кеша
        if let diskCached = try? cacheService.load() {
            memoryCache.set(diskCached)
            updateDataStatus(.availableLocally(.diskCache))
            logger.info("✅ Загружено из дискового кеша: \(diskCached.signs.count) жестов, \(diskCached.categories.count) категорий")
            PerformanceService.addAttribute(trace, name: "source", value: "disk_cache")
            PerformanceService.incrementMetric(trace, name: "signs_count", by: Int64(diskCached.signs.count))
            PerformanceService.incrementMetric(trace, name: "categories_count", by: Int64(diskCached.categories.count))
            await scheduleBackgroundSyncIfNeeded()
            return diskCached
        }
        
        logger.info("🌐 Кеш пуст, загрузка с сервера...")
        PerformanceService.addAttribute(trace, name: "source", value: "server")
        return try await loadFromServer(trace: trace)
    }
    
    // MARK: - Server Sync
    
    private func loadFromServer(trace: Trace? = nil) async throws -> SyncData {
        guard await networkMonitor.checkConnection() else {
            logger.error("❌ Первый запуск без интернета — данные недоступны")
            updateDataStatus(.noData(.noInternet))
            if let trace = trace {
                PerformanceService.addAttribute(trace, name: "error", value: "no_internet")
            }
            throw SignRepositoryError.noDataAvailable
        }
        
        do {
            logger.info("🔄 Первая загрузка с сервера...")
            
            let syncData = try await syncRepository.fetchAllData {
                throw SignRepositoryError.noDataAvailable
            }
            
            saveToAllCaches(syncData)
            updateDataStatus(.updated)
            logger.info("✅ Первая загрузка завершена успешно")
            
            if let trace = trace {
                PerformanceService.incrementMetric(trace, name: "signs_count", by: Int64(syncData.signs.count))
                PerformanceService.incrementMetric(trace, name: "categories_count", by: Int64(syncData.categories.count))
            }
            
            return syncData
            
        } catch {
            logger.error("❌ Ошибка загрузки с сервера: \(error.localizedDescription)")
            updateDataStatus(.noData(await dataStatusReason(for: error)))
            if let trace = trace {
                PerformanceService.addAttribute(trace, name: "error", value: error.localizedDescription)
            }
            throw SignRepositoryError.from(error)
        }
    }
    
    // MARK: - Cache Management
    
    func saveToAllCaches(_ data: SyncData) {
        memoryCache.set(data)
        
        do {
            try cacheService.save(data)
            logger.info("✅ Данные сохранены в оба кеша")
        } catch {
            logger.warning("⚠️ Ошибка сохранения в дисковый кеш: \(error.localizedDescription)")
        }
    }

    func updateDataStatus(_ status: RepositoryDataStatus) {
        dataStatusLock.withLock {
            guard dataStatusSubject.value != status else { return }
            dataStatusSubject.send(status)
        }
    }

    func dataStatusReason(for error: Error) async -> DataStatusReason {
        if let syncError = error as? SyncError {
            switch syncError {
            case .noInternet:
                return .noInternet
            case .serverUnavailable, .serverError, .decodingError, .invalidResponse:
                return .serverUnavailable
            case .networkError:
                return await networkMonitor.checkConnection() ? .serverUnavailable : .noInternet
            }
        }

        return await networkMonitor.checkConnection() ? .serverUnavailable : .noInternet
    }
}
