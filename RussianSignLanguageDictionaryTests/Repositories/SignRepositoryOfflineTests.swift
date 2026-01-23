import XCTest
@testable import RussianSignLanguageDictionary

/// Тесты для проверки работы SignRepository с интернетом и без (офлайн-режим)
final class SignRepositoryOfflineTests: XCTestCase {
    
    var sut: SignRepository!
    var mockNetworkMonitor: MockNetworkMonitor!
    var mockSyncRepository: MockSyncRepository!
    var cacheService: CacheService!
    
    override func setUp() {
        super.setUp()
        mockNetworkMonitor = MockNetworkMonitor()
        mockSyncRepository = MockSyncRepository()
        cacheService = CacheService()
        
        sut = SignRepository(
            syncRepository: mockSyncRepository,
            cacheService: cacheService,
            networkMonitor: mockNetworkMonitor
        )
    }
    
    override func tearDown() {
        // Очищаем кеш
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let cacheURL = documentsURL.appendingPathComponent("cached_signs_data.json")
            try? FileManager.default.removeItem(at: cacheURL)
        }
        sut = nil
        mockNetworkMonitor = nil
        mockSyncRepository = nil
        cacheService = nil
        super.tearDown()
    }
    
    // MARK: - Tests: Загрузка жестов
    
    /// Тест: Загрузка жестов с интернетом должна работать и сохранять в кеш
    func testLoadAllSignsWithInternet_SavesToCache() async throws {
        // Arrange
        mockNetworkMonitor.simulateInternetRestored()
        mockSyncRepository.shouldSucceed = true
        
        // Act
        let signs1 = try await sut.loadAllSigns()
        
        // Симулируем потерю интернета
        mockNetworkMonitor.simulateNoInternet()
        mockSyncRepository.shouldSucceed = false
        
        // Пытаемся загрузить снова (должно быть из кеша)
        let signs2 = try await sut.loadAllSigns()
        
        // Assert
        XCTAssertFalse(signs1.isEmpty, "Жесты должны быть загружены")
        XCTAssertFalse(signs2.isEmpty, "Жесты должны быть загружены из кеша")
        XCTAssertEqual(signs1.count, signs2.count, "Количество жестов должно совпадать")
    }
    
    /// Тест: Загрузка жестов без интернета, но с кешем должна работать
    func testLoadAllSignsWithoutInternet_WithCache_Success() async throws {
        // Arrange
        // Сначала загружаем с интернетом
        mockNetworkMonitor.simulateInternetRestored()
        mockSyncRepository.shouldSucceed = true
        _ = try await sut.loadAllSigns()
        
        // Теперь симулируем отсутствие интернета
        mockNetworkMonitor.simulateNoInternet()
        mockSyncRepository.shouldSucceed = false
        
        // Act
        let signs = try await sut.loadAllSigns()
        
        // Assert
        XCTAssertFalse(signs.isEmpty, "Жесты должны быть загружены из кеша")
    }
    
    /// Тест: Загрузка жестов без интернета и без кеша должна выбрасывать ошибку
    func testLoadAllSignsWithoutInternet_NoCache_ThrowsError() async {
        // Arrange
        mockNetworkMonitor.simulateNoInternet()
        mockSyncRepository.shouldSucceed = false
        
        // Act & Assert
        do {
            _ = try await sut.loadAllSigns()
            XCTFail("Должна быть выброшена ошибка noDataAvailable")
        } catch let error as SignRepositoryError {
            XCTAssertEqual(error, .noDataAvailable, "Должна быть ошибка отсутствия данных")
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }
    
    // MARK: - Tests: Загрузка категорий
    
    /// Тест: Загрузка категорий с интернетом должна работать
    func testLoadCategoriesWithInternet_Success() async throws {
        // Arrange
        mockNetworkMonitor.simulateInternetRestored()
        mockSyncRepository.shouldSucceed = true
        
        // Act
        let categories1 = try await sut.loadCategories()
        
        // Симулируем потерю интернета
        mockNetworkMonitor.simulateNoInternet()
        mockSyncRepository.shouldSucceed = false
        
        // Пытаемся загрузить снова (должно быть из кеша)
        let categories2 = try await sut.loadCategories()
        
        // Assert
        XCTAssertFalse(categories1.isEmpty, "Категории должны быть загружены")
        XCTAssertFalse(categories2.isEmpty, "Категории должны быть загружены из кеша")
        XCTAssertEqual(categories1.count, categories2.count, "Количество категорий должно совпадать")
    }
    
    /// Тест: Загрузка категорий без интернета, но с кешем должна работать
    func testLoadCategoriesWithoutInternet_WithCache_Success() async throws {
        // Arrange
        // Сначала загружаем с интернетом
        mockNetworkMonitor.simulateInternetRestored()
        mockSyncRepository.shouldSucceed = true
        _ = try await sut.loadCategories()
        
        // Теперь симулируем отсутствие интернета
        mockNetworkMonitor.simulateNoInternet()
        mockSyncRepository.shouldSucceed = false
        
        // Act
        let categories = try await sut.loadCategories()
        
        // Assert
        XCTAssertFalse(categories.isEmpty, "Категории должны быть загружены из кеша")
    }
    
    /// Тест: Загрузка категорий без интернета и без кеша должна выбрасывать ошибку
    func testLoadCategoriesWithoutInternet_NoCache_ThrowsError() async {
        // Arrange
        mockNetworkMonitor.simulateNoInternet()
        mockSyncRepository.shouldSucceed = false
        
        // Act & Assert
        do {
            _ = try await sut.loadCategories()
            XCTFail("Должна быть выброшена ошибка noDataAvailable")
        } catch let error as SignRepositoryError {
            XCTAssertEqual(error, .noDataAvailable, "Должна быть ошибка отсутствия данных")
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }
    
    // MARK: - Tests: Поиск жестов
    
    /// Тест: Поиск жестов в офлайн-режиме должен работать с кешированными данными
    func testSearchSignsOffline_WithCache_Success() async throws {
        // Arrange
        // Сначала загружаем с интернетом
        mockNetworkMonitor.simulateInternetRestored()
        mockSyncRepository.shouldSucceed = true
        _ = try await sut.loadAllSigns()
        
        // Симулируем потерю интернета
        mockNetworkMonitor.simulateNoInternet()
        mockSyncRepository.shouldSucceed = false
        
        // Act
        let results = try await sut.searchSigns(query: "привет")
        
        // Assert
        // Результаты могут быть пустыми, но ошибки быть не должно
        XCTAssertNotNil(results)
    }
}
