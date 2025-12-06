import Foundation
import os.log

/// Репозиторий для работы с данными о жестах
final class SignRepository: SignRepositoryProtocol {
    private let logger = Logger(subsystem: "com.rsl.SignRepository", category: "repository")
    // MARK: - Properties
    
    /// Имя JSON файла в Bundle (для обратной совместимости)
    private let fileName: String
    
    /// Репозиторий синхронизации (опционально)
    private let syncRepository: SyncRepositoryProtocol?
    
    /// Сервис кеширования (опционально)
    private let cacheService: CacheService?
    
    /// Монитор сети
    private let networkMonitor: NetworkMonitor
    
    /// Кэш загруженных данных (для старого способа)
    private var cachedData: SignsData?
    
    /// Кэш синхронизированных данных
    private var syncedData: SyncData?
    
    /// Очередь для thread-safe операций с кэшем
    private let cacheQueue = DispatchQueue(label: "com.rsl.signRepository.cache")
    
    // MARK: - Initialization
    
    /// Инициализатор репозитория с синхронизацией
    /// - Parameters:
    ///   - syncRepository: Репозиторий синхронизации
    ///   - cacheService: Сервис кеширования
    ///   - networkMonitor: Монитор сети
    init(
        syncRepository: SyncRepositoryProtocol? = nil,
        cacheService: CacheService? = nil,
        networkMonitor: NetworkMonitor = NetworkMonitor()
    ) {
        self.syncRepository = syncRepository
        self.cacheService = cacheService
        self.networkMonitor = networkMonitor
        self.fileName = "signs_data" // Для обратной совместимости
    }
    
    /// Инициализатор репозитория для обратной совместимости (загрузка из Bundle)
    /// - Parameter fileName: Имя JSON файла в Bundle (по умолчанию "signs_data")
    convenience init(fileName: String = "signs_data") {
        self.init(syncRepository: nil, cacheService: nil)
    }
    
    // MARK: - SignRepositoryProtocol
    
    func loadAllSigns() async throws -> [Sign] {
        // Если настроена синхронизация, используем её
        if let syncRepository = syncRepository, let cacheService = cacheService {
            return try await loadSignsWithSync(syncRepository: syncRepository, cacheService: cacheService)
        }
        
        // Иначе используем старый способ (из Bundle)
        let data = try await loadData()
        return data.signs
    }
    
    func loadCategories() async throws -> [Category] {
        // Если настроена синхронизация, используем её
        if let syncRepository = syncRepository, let cacheService = cacheService {
            let syncData = try await loadDataWithSync(syncRepository: syncRepository, cacheService: cacheService)
            return syncData.categories.sorted { $0.order < $1.order }
        }
        
        // Иначе используем старый способ (из Bundle)
        let data = try await loadData()
        return data.categories.sorted { $0.order < $1.order }
    }
    
    func getSign(byId id: String) async throws -> Sign? {
        let signs = try await loadAllSigns()
        return signs.first { $0.id == id }
    }
    
    func getSigns(byCategory categoryId: String) async throws -> [Sign] {
        let signs = try await loadAllSigns()
        return signs.filter { $0.category == categoryId }
    }
    
    func searchSigns(query: String) async throws -> [Sign] {
        guard !query.isEmpty else {
            return []
        }
        
        let signs = try await loadAllSigns()
        let lowercasedQuery = query.lowercased()
        
        return signs.filter { sign in
            // Поиск по слову
            if sign.word.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            // Поиск по ключевым словам (если есть)
            if let keywords = sign.keywords, keywords.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
                return true
            }
            
            // Поиск по описанию
            if sign.description.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            return false
        }
    }
    
    // MARK: - Private Methods (Синхронизация)
    
    /// Загружает жесты с использованием синхронизации
    private func loadSignsWithSync(
        syncRepository: SyncRepositoryProtocol,
        cacheService: CacheService
    ) async throws -> [Sign] {
        let syncData = try await loadDataWithSync(syncRepository: syncRepository, cacheService: cacheService)
        return syncData.signs
    }
    
    /// Загружает данные с использованием синхронизации
    private func loadDataWithSync(
        syncRepository: SyncRepositoryProtocol,
        cacheService: CacheService
    ) async throws -> SyncData {
        // Проверка кэша в памяти
        if let cached = loadFromMemoryCache() {
            return cached
        }
        
        // Попытка синхронизации с сервером
        if let synced = try? await trySyncWithServer(syncRepository: syncRepository, cacheService: cacheService) {
            return synced
        }
        
        // Fallback на локальный кеш
        return try loadFromLocalCache(cacheService: cacheService)
    }
    
    /// Загружает данные из кэша памяти
    private func loadFromMemoryCache() -> SyncData? {
        if let cached = cacheQueue.sync(execute: { syncedData }) {
            logger.info("✅ Данные загружены из кэша памяти (\(cached.signs.count) жестов, \(cached.categories.count) категорий)")
            return cached
        }
        return nil
    }
    
    /// Пытается синхронизировать данные с сервером
    private func trySyncWithServer(
        syncRepository: SyncRepositoryProtocol,
        cacheService: CacheService
    ) async throws -> SyncData {
        // Проверка доступности интернета
        let isConnected = await networkMonitor.checkConnection()
        guard isConnected else {
            logger.warning("⚠️ Нет подключения к интернету, загрузка из кеша...")
            throw SignRepositoryError.noDataAvailable
        }
        
        // Попытка синхронизации с сервером
        do {
            logger.info("🔄 Попытка синхронизации с сервером...")
            let syncData = try await syncRepository.fetchAllData()
            
            // Сохранение в кеш
            saveToCache(syncData, cacheService: cacheService)
            
            // Сохранение в кэш памяти
            saveToMemoryCache(syncData)
            
            return syncData
        } catch let error as SyncError {
            // Если нет интернета, используем кеш без показа ошибки
            if case .noInternet = error {
                logger.warning("⚠️ Нет интернета, загрузка из кеша...")
            } else {
                logger.warning("⚠️ Ошибка синхронизации: \(error.localizedDescription), загрузка из кеша...")
            }
            throw SignRepositoryError.noDataAvailable
        } catch {
            logger.warning("⚠️ Неизвестная ошибка синхронизации: \(error.localizedDescription), загрузка из кеша...")
            throw SignRepositoryError.noDataAvailable
        }
    }
    
    /// Сохраняет данные в кеш
    private func saveToCache(_ data: SyncData, cacheService: CacheService) {
        do {
            try cacheService.save(data)
            logger.info("✅ Данные синхронизированы и сохранены в кеш")
        } catch {
            logger.warning("⚠️ Ошибка сохранения в кеш: \(error.localizedDescription)")
        }
    }
    
    /// Сохраняет данные в кэш памяти
    private func saveToMemoryCache(_ data: SyncData) {
        cacheQueue.sync {
            syncedData = data
        }
    }
    
    /// Загружает данные из локального кеша
    private func loadFromLocalCache(cacheService: CacheService) throws -> SyncData {
        if let cached = try? cacheService.load() {
            saveToMemoryCache(cached)
            logger.info("✅ Данные загружены из локального кеша (\(cached.signs.count) жестов, \(cached.categories.count) категорий)")
            return cached
        }
        
        // Если кеш тоже пуст, выбрасываем ошибку
        logger.error("❌ Данные недоступны (нет кеша и нет интернета)")
        throw SignRepositoryError.noDataAvailable
    }
    
    // MARK: - Private Methods (Обратная совместимость - Bundle)
    
    /// Загружает и кэширует данные из JSON файла (старый способ)
    /// - Returns: Загруженные данные
    /// - Throws: SignRepositoryError в случае ошибки
    private func loadData() async throws -> SignsData {
        // Проверка кэша
        if let cached = loadCachedData() {
            return cached
        }
        
        // Загрузка из Bundle
        let data = try loadJSONFromBundle()
        let signsData = try decodeSignsData(data)
        
        // Сохранение в кэш
        saveCachedData(signsData)
        
        return signsData
    }
    
    /// Загружает данные из кэша
    private func loadCachedData() -> SignsData? {
        if let cached = cacheQueue.sync(execute: { cachedData }) {
            logger.info("✅ Данные загружены из кэша (\(cached.signs.count) жестов, \(cached.categories.count) категорий)")
            return cached
        }
        return nil
    }
    
    /// Загружает JSON из Bundle
    private func loadJSONFromBundle() throws -> Data {
        logger.debug("📂 Поиск файла '\(self.fileName).json' в Bundle...")
        logger.debug("📂 Bundle path: \(Bundle.main.bundlePath)")
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            logger.error("❌ Файл '\(self.fileName).json' НЕ НАЙДЕН в Bundle!")
            logger.error("💡 Решение: Добавьте файл в Xcode проект (см. FIX_JSON_LOADING.md)")
            throw SignRepositoryError.fileNotFound
        }
        
        logger.debug("✅ Файл найден: \(url.path)")
        
        do {
            let data = try Data(contentsOf: url)
            logger.debug("✅ Файл прочитан (\(data.count) bytes)")
            return data
        } catch {
            logger.error("❌ Ошибка чтения файла: \(error.localizedDescription)")
            throw SignRepositoryError.unableToReadFile
        }
    }
    
    /// Декодирует данные из JSON
    private func decodeSignsData(_ data: Data) throws -> SignsData {
        logger.debug("🔄 Декодирование JSON...")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let signsData = try decoder.decode(SignsData.self, from: data)
            logger.info("✅ JSON успешно декодирован!")
            logger.debug("   📊 Жестов: \(signsData.signs.count)")
            logger.debug("   📊 Категорий: \(signsData.categories.count)")
            logger.debug("   📊 Версия: \(signsData.version ?? "не указана")")
            return signsData
        } catch {
            logger.error("❌ Ошибка декодирования JSON: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                logger.error("   Детали: \(String(describing: decodingError))")
            }
            throw SignRepositoryError.decodingError(error)
        }
    }
    
    /// Сохраняет данные в кэш
    private func saveCachedData(_ data: SignsData) {
        cacheQueue.sync {
            cachedData = data
        }
        logger.debug("💾 Данные сохранены в кэш")
    }
}

