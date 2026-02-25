import XCTest
@testable import RussianSignLanguageDictionary

/// Тесты для проверки работы VideoRepository с интернетом и без
final class VideoRepositoryOfflineTests: XCTestCase {
    
    var sut: VideoRepository!
    var mockNetworkMonitor: MockNetworkMonitor!
    
    override func setUp() {
        super.setUp()
        mockNetworkMonitor = MockNetworkMonitor()
        let videoCacheService = VideoCacheService()
        sut = VideoRepository(
            videoCacheService: videoCacheService,
            networkMonitor: mockNetworkMonitor
        )
        
        // Очищаем кеш перед каждым тестом
        videoCacheService.clearAllCache()
    }
    
    override func tearDown() {
        sut?.clearCache()
        VideoCacheService().clearAllCache()
        sut = nil
        mockNetworkMonitor = nil
        super.tearDown()
    }
    
    // MARK: - Test Data
    
    private func createMockVideo() -> SignVideo {
        return SignVideo(
            id: 1,
            url: "https://example.com/video.mp4",
            contextDescription: "Тестовое видео",
            order: 1,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    // MARK: - Tests: Обычное видео (не из избранного)
    
    /// Тест: Загрузка видео без интернета (не из избранного) должна выбрасывать ошибку
    func testGetVideoURLWithoutInternet_NonFavorite_ThrowsError() async {
        // Arrange
        mockNetworkMonitor.simulateNoInternet()
        let video = createMockVideo()
        
        // Act & Assert
        do {
            _ = try await sut.getVideoURL(for: video, useFavoritesCache: false)
            XCTFail("Должна быть выброшена ошибка noInternetConnection")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, .noInternetConnection, "Должна быть ошибка отсутствия интернета")
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }
    
    /// Тест: Загрузка видео с интернетом (не из избранного) должна работать
    /// Примечание: требует сетевого доступа (скачивает видео в tmp/)
    func testGetVideoURLWithInternet_NonFavorite_Success() async throws {
        // Arrange
        mockNetworkMonitor.simulateInternetRestored()
        let video = createMockVideo()
        
        // Act
        let url = try await sut.getVideoURL(for: video, useFavoritesCache: false)
        
        // Assert
        XCTAssertNotNil(url)
        // Краткосрочный кеш скачивает видео в tmp/ и возвращает локальный file URL
        XCTAssertTrue(url.isFileURL, "Краткосрочный кеш должен возвращать локальный file URL")
    }
    
    // MARK: - Tests: Избранное видео (с долгосрочным кешем)
    
    /// Тест: Загрузка видео из избранного без интернета, но с кешем должна работать
    func testGetVideoURLWithoutInternet_Favorite_WithCache_Success() async throws {
        // Arrange
        mockNetworkMonitor.simulateInternetRestored()
        let video = createMockVideo()
        
        // Сначала загружаем видео в кеш (с интернетом)
        _ = try await sut.getVideoURL(for: video, useFavoritesCache: true)
        
        // Теперь симулируем отсутствие интернета
        mockNetworkMonitor.simulateNoInternet()
        
        // Act
        let url = try await sut.getVideoURL(for: video, useFavoritesCache: true)
        
        // Assert
        XCTAssertNotNil(url)
        XCTAssertEqual(url.absoluteString, video.url)
    }
    
    /// Тест: Загрузка видео из избранного без интернета и без кеша должна выбрасывать ошибку
    func testGetVideoURLWithoutInternet_Favorite_NoCache_ThrowsError() async {
        // Arrange
        mockNetworkMonitor.simulateNoInternet()
        let video = createMockVideo()
        
        // Act & Assert
        do {
            _ = try await sut.getVideoURL(for: video, useFavoritesCache: true)
            XCTFail("Должна быть выброшена ошибка videoNotCached")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, .videoNotCached, "Должна быть ошибка отсутствия видео в кеше")
        } catch {
            XCTFail("Неожиданная ошибка: \(error)")
        }
    }
    
    /// Тест: Загрузка видео из избранного с интернетом должна работать и сохранять в кеш
    func testGetVideoURLWithInternet_Favorite_SavesToCache() async throws {
        // Arrange
        mockNetworkMonitor.simulateInternetRestored()
        let video = createMockVideo()
        
        // Act
        let url1 = try await sut.getVideoURL(for: video, useFavoritesCache: true)
        
        // Симулируем потерю интернета
        mockNetworkMonitor.simulateNoInternet()
        
        // Пытаемся загрузить снова (должно быть из кеша)
        let url2 = try await sut.getVideoURL(for: video, useFavoritesCache: true)
        
        // Assert
        XCTAssertNotNil(url1)
        XCTAssertNotNil(url2)
        XCTAssertEqual(url1, url2)
    }
    
    // MARK: - Tests: Предзагрузка
    
    /// Тест: Предзагрузка видео в долгосрочный кеш должна работать
    func testPreloadVideoToFavoritesCache() async throws {
        // Arrange
        mockNetworkMonitor.simulateInternetRestored()
        let video = createMockVideo()
        
        // Act
        try await sut.preloadVideo(video: video, useFavoritesCache: true)
        
        // Симулируем потерю интернета
        mockNetworkMonitor.simulateNoInternet()
        
        // Пытаемся загрузить (должно быть из кеша)
        let url = try await sut.getVideoURL(for: video, useFavoritesCache: true)
        
        // Assert
        XCTAssertNotNil(url)
        XCTAssertEqual(url.absoluteString, video.url)
    }
    
    /// Тест: Предзагрузка без интернета должна выбрасывать ошибку
    func testPreloadVideoWithoutInternet_ThrowsError() async {
        // Arrange
        mockNetworkMonitor.simulateNoInternet()
        let video = createMockVideo()
        
        // Act & Assert
        do {
            try await sut.preloadVideo(video: video, useFavoritesCache: true)
            XCTFail("Должна быть выброшена ошибка")
        } catch {
            // Ожидаем ошибку (может быть разной в зависимости от реализации)
            XCTAssertTrue(error is VideoRepositoryError || error is URLError)
        }
    }
}
