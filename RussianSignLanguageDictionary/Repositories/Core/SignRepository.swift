import Foundation
import os.log
import Combine

/// Репозиторий для работы с данными о жестах
final class SignRepository: SignRepositoryProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.SignRepository", category: "repository")
    
    private let syncRepository: SyncRepositoryProtocol
    private let cacheService: CacheService
    private let networkMonitor: NetworkMonitorProtocol
    
    private let memoryCache = MemoryCacheManager<SyncData>(label: "com.rsl.signRepository.memoryCache")
    private let loadCoordinator = DataLoadCoordinator<SyncData>(
        subsystem: "com.rsl.SignRepository",
        category: "LoadCoordinator"
    )
    
    /// Защита от множественных фоновых синхронизаций
    private var backgroundSyncTask: Task<Void, Never>?
    
    // MARK: - Publishers
    
    private let dataUpdatedSubject = PassthroughSubject<SyncData, Never>()
    var dataUpdatedPublisher: AnyPublisher<SyncData, Never> {
        dataUpdatedSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init(
        syncRepository: SyncRepositoryProtocol,
        cacheService: CacheService,
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
    
    // MARK: - Data Loading
    
    private func loadDataWithSync() async throws -> SyncData {
        if let cached = memoryCache.get() {
            logger.debug("📦 Данные из memory cache (быстрый путь)")
            scheduleBackgroundSyncIfNeeded()
            return cached
        }
        
        logger.info("🔄 Начало загрузки данных (memory cache пуст)")
        return try await loadCoordinator.getOrCreateTask { [weak self] in
            guard let self else { throw SignRepositoryError.noDataAvailable }
            return try await self.performDataLoad()
        }
    }
    
    private func performDataLoad() async throws -> SyncData {
        logger.info("🔍 Проверка локального кеша...")
        
        // Попытка загрузить из дискового кеша
        if let diskCached = try? cacheService.load() {
            memoryCache.set(diskCached)
            logger.info("✅ Загружено из дискового кеша: \(diskCached.signs.count) жестов, \(diskCached.categories.count) категорий")
            scheduleBackgroundSyncIfNeeded()
            return diskCached
        }
        
        logger.info("🌐 Кеш пуст, загрузка с сервера...")
        return try await loadFromServer()
    }
    
    // MARK: - Server Sync
    
    private func loadFromServer() async throws -> SyncData {
        guard await networkMonitor.checkConnection() else {
            logger.error("❌ Первый запуск без интернета — данные недоступны")
            throw SignRepositoryError.noDataAvailable
        }
        
        do {
            logger.info("🔄 Первая загрузка с сервера...")
            
            let syncData = try await syncRepository.fetchAllData {
                throw SignRepositoryError.noDataAvailable
            }
            
            saveToAllCaches(syncData)
            logger.info("✅ Первая загрузка завершена успешно")
            return syncData
            
        } catch {
            logger.error("❌ Ошибка загрузки с сервера: \(error.localizedDescription)")
            throw SignRepositoryError.from(error)
        }
    }
    
    // MARK: - Background Sync
    
    private func scheduleBackgroundSyncIfNeeded() {
        guard backgroundSyncTask == nil || backgroundSyncTask?.isCancelled == true else {
            logger.debug("⏭️ Фоновая синхронизация уже запущена")
            return
        }
        
        backgroundSyncTask = Task { [weak self] in
            await self?.performBackgroundSync()
        }
    }
    
    private func performBackgroundSync() async {
        guard await networkMonitor.checkConnection() else {
            logger.debug("📴 Нет интернета для фоновой синхронизации")
            return
        }
        
        do {
            logger.info("🔄 Фоновая синхронизация...")
            
            let currentData = memoryCache.get()
            let syncData = try await syncRepository.fetchAllData { [weak self] in
                guard let cached = self?.memoryCache.get() else {
                    throw SignRepositoryError.noDataAvailable
                }
                return cached
            }
            
            guard currentData?.lastUpdated != syncData.lastUpdated else {
                logger.info("ℹ️ Данные не изменились")
                return
            }
            
            logger.info("🆕 Обнаружены изменения!")
            saveToAllCaches(syncData)
            dataUpdatedSubject.send(syncData)
            logger.info("✅ Фоновая синхронизация завершена с обновлением UI")
            
        } catch {
            logger.warning("⚠️ Фоновая синхронизация не удалась: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cache Management
    
    private func saveToAllCaches(_ data: SyncData) {
        memoryCache.set(data)
        
        do {
            try cacheService.save(data)
            logger.info("✅ Данные сохранены в оба кеша")
        } catch {
            logger.warning("⚠️ Ошибка сохранения в дисковый кеш: \(error.localizedDescription)")
        }
    }
}
