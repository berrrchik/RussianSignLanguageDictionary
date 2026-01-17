import Foundation
import os.log
import Combine

/// Репозиторий для работы с данными о жестах
final class SignRepository: SignRepositoryProtocol {
    private let logger = Logger(subsystem: "com.rsl.SignRepository", category: "repository")
    
    // MARK: - Properties
    
    private let syncRepository: SyncRepositoryProtocol
    private let cacheService: CacheService
    private let networkMonitor: NetworkMonitorProtocol
    
    private var syncedData: SyncData?
    private let cacheQueue = DispatchQueue(label: "com.rsl.signRepository.cache")
    
    // Publisher для уведомления об обновлении данных
    private let dataUpdatedSubject = PassthroughSubject<SyncData, Never>()
    var dataUpdatedPublisher: AnyPublisher<SyncData, Never> {
        dataUpdatedSubject.eraseToAnyPublisher()
    }
    
    // Защита от множественных фоновых синхронизаций
    private var backgroundSyncTask: Task<Void, Never>?
    
    private actor LoadCoordinator {
        private var activeTask: Task<SyncData, Error>?
        private let logger = Logger(subsystem: "com.rsl.SignRepository", category: "LoadCoordinator")
        
        func getOrCreateTask(
            perform work: @escaping @Sendable () async throws -> SyncData
        ) async throws -> SyncData {
            if let existingTask = activeTask {
                logger.info("⏳ LoadCoordinator: Обнаружена активная задача загрузки, ожидание...")
                return try await existingTask.value
            }
            
            logger.info("🚀 LoadCoordinator: Создание новой задачи загрузки")
            let newTask = Task<SyncData, Error> {
                defer {
                    Task { await self.clearTask() }
                }
                return try await work()
            }
            
            activeTask = newTask
            let result = try await newTask.value
            logger.info("✅ LoadCoordinator: Задача загрузки завершена")
            return result
        }
        
        private func clearTask() {
            activeTask = nil
            logger.debug("🧹 LoadCoordinator: Задача очищена")
        }
    }
    
    private let loadCoordinator = LoadCoordinator()
    
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
        let lowercasedQuery = query.lowercased()
        
        return signs.filter { sign in
            sign.word.lowercased().contains(lowercasedQuery) ||
            (sign.keywords?.contains(where: { $0.lowercased().contains(lowercasedQuery) }) ?? false) ||
            sign.description.lowercased().contains(lowercasedQuery)
        }
    }
    
    // MARK: - Private Methods (Синхронизация)
    
    private func loadDataWithSync() async throws -> SyncData {
        if let cached = loadFromMemoryCache() {
            logger.debug("📦 loadDataWithSync: Данные из кеша памяти (быстрый путь)")
            startBackgroundSyncIfNeeded()
            return cached
        }
        
        logger.info("🔄 loadDataWithSync: Начало загрузки данных (кеш памяти пуст)")
        return try await loadCoordinator.getOrCreateTask { [weak self] in
            guard let self = self else {
                throw SignRepositoryError.noDataAvailable
            }
            
            logger.debug("📥 loadDataWithSync: Выполнение performDataLoad()")
            return try await self.performDataLoad()
        }
    }
    
    private func performDataLoad() async throws -> SyncData {
        logger.info("🔍 performDataLoad: Начало загрузки данных (проверка локального кеша)...")
        
        do {
            if let cached = try cacheService.load() {
                saveToMemoryCache(cached)
                logger.info("✅ Данные загружены из локального кеша (\(cached.signs.count) жестов, \(cached.categories.count) категорий)")
                
                startBackgroundSyncIfNeeded()
                
                return cached
            }
        } catch {
            logger.error("❌ Ошибка загрузки из локального кеша: \(error.localizedDescription)")
        }
        
        logger.info("🌐 Нет кеша, попытка загрузки с сервера...")
        return try await trySyncWithServer()
    }
    
    private func startBackgroundSyncIfNeeded() {
        guard backgroundSyncTask == nil || backgroundSyncTask?.isCancelled == true else {
            logger.debug("⏭️ Фоновая синхронизация уже выполняется, пропускаем")
            return
        }
        
        backgroundSyncTask = Task { [weak self] in
            await self?.backgroundSyncIfNeeded()
        }
    }
    
    private func backgroundSyncIfNeeded() async {
        let isConnected = await networkMonitor.checkConnection()
        guard isConnected else {
            logger.debug("📴 Фоновая синхронизация пропущена - нет интернета")
            return
        }
        
        do {
            logger.info("🔄 Фоновая синхронизация...")
            
            let currentData = loadFromMemoryCache()
            let syncData = try await syncRepository.fetchAllData(
                cachedDataProvider: { [weak self] in
                    guard let cached = self?.loadFromMemoryCacheQuiet() else {
                        throw SyncError.networkError(
                            NSError(domain: "SignRepository", code: -1, userInfo: [
                                NSLocalizedDescriptionKey: "Memory cache unavailable for 304"
                            ])
                        )
                    }
                    return cached
                }
            )
            
            let hasChanges = currentData?.lastUpdated != syncData.lastUpdated
            
            if hasChanges {
                logger.info("🆕 Обнаружены изменения данных!")
                
                saveToCache(syncData)
                saveToMemoryCache(syncData)
                dataUpdatedSubject.send(syncData)
                
                logger.info("✅ Фоновая синхронизация завершена с обновлением UI")
            } else {
                logger.info("ℹ️ Данные не изменились, обновление не требуется")
            }
        } catch {
            logger.warning("⚠️ Фоновая синхронизация не удалась: \(error.localizedDescription)")
        }
    }
    
    private func loadFromMemoryCache() -> SyncData? {
        return cacheQueue.sync { syncedData }
    }
    
    private func loadFromMemoryCacheQuiet() -> SyncData? {
        return cacheQueue.sync { syncedData }
    }
    
    private func trySyncWithServer() async throws -> SyncData {
        let isConnected = await networkMonitor.checkConnection()
        guard isConnected else {
            logger.error("❌ Первый запуск без интернета - данные недоступны")
            throw SignRepositoryError.noDataAvailable
        }
        
        do {
            logger.info("🔄 Первая загрузка данных с сервера...")
            

            let syncData = try await syncRepository.fetchAllData { [weak self] in
                throw SyncError.networkError(
                    NSError(domain: "SignRepository", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "First load, no memory cache"
                    ])
                )
            }
            
            saveToCache(syncData)
            saveToMemoryCache(syncData)
            
            logger.info("✅ Первая загрузка завершена успешно")
            return syncData
        } catch let error as SyncError {
            logger.error("❌ Ошибка первой загрузки: \(error.localizedDescription)")
            throw SignRepositoryError.noDataAvailable
        } catch {
            logger.error("❌ Неизвестная ошибка первой загрузки: \(error.localizedDescription)")
            throw SignRepositoryError.noDataAvailable
        }
    }
    
    private func saveToCache(_ data: SyncData) {
        do {
            try cacheService.save(data)
            logger.info("✅ Данные синхронизированы и сохранены в кеш")
        } catch {
            logger.warning("⚠️ Ошибка сохранения в кеш: \(error.localizedDescription)")
        }
    }
    
    private func saveToMemoryCache(_ data: SyncData) {
        cacheQueue.sync {
            syncedData = data
        }
    }
}
