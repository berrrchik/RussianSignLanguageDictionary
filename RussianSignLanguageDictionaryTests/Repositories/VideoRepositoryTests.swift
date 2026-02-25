import XCTest
@testable import RussianSignLanguageDictionary

final class VideoRepositoryTests: XCTestCase {
    
    var sut: VideoRepository!
    var mockNetworkMonitor: MockNetworkMonitor!
    
    override func setUp() {
        super.setUp()
        mockNetworkMonitor = MockNetworkMonitor()
        mockNetworkMonitor.setConnected(true)
        let videoCacheService = VideoCacheService()
        sut = VideoRepository(
            videoCacheService: videoCacheService,
            networkMonitor: mockNetworkMonitor
        )
    }
    
    override func tearDown() {
        sut?.clearCache()
        sut = nil
        mockNetworkMonitor = nil
        super.tearDown()
    }
    
    // MARK: - Test Data
    
    private func createMockSign() -> Sign {
        return Sign(
            id: "sign_001",
            word: "Привет",
            description: "Приветствие",
            categoryId: "emotions",
            videos: [
                SignVideo(
                    id: 1,
                    url: "https://lesulvngqpvgepijazin.supabase.co/storage/v1/object/public/signs/emotions/video_001.mp4",
                    contextDescription: "Основное видео",
                    order: 0,
                    createdAt: nil,
                    updatedAt: nil
                )
            ],
            synonyms: nil
        )
    }
    
    private func createMockVideo(id: Int = 1) -> SignVideo {
        return SignVideo(
            id: id,
            url: "https://lesulvngqpvgepijazin.supabase.co/storage/v1/object/public/signs/test/video_\(id).mp4",
            contextDescription: "Test video \(id)",
            order: 1,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    // MARK: - Basic Tests
    
    func testGetVideoURL() async throws {
        let sign = createMockSign()
        
        let url = try await sut.getVideoURL(for: sign)
        
        XCTAssertNotNil(url)
        XCTAssertEqual(url.absoluteString, sign.videos?.first?.url)
    }
    
    func testGetVideoURLCaching() async throws {
        let sign = createMockSign()
        
        let url1 = try await sut.getVideoURL(for: sign)
        
        let url2 = try await sut.getVideoURL(for: sign)
        
        XCTAssertEqual(url1, url2)
    }
    
    func testPreloadVideo() async throws {
        let sign = createMockSign()
        
        try await sut.preloadVideo(for: sign)
        
        let url = try await sut.getVideoURL(for: sign)
        XCTAssertNotNil(url)
    }
    
    func testClearCache() async throws {
        let sign = createMockSign()
        _ = try await sut.getVideoURL(for: sign)
        
        sut.clearCache()
        
        let url = try await sut.getVideoURL(for: sign)
        XCTAssertNotNil(url)
    }
    
    func testGetVideoURLWithInvalidURL() async {
        // Жест без видео должен выбрасывать ошибку
        let signWithoutVideos = Sign(
            id: "sign_invalid",
            word: "Test",
            description: "Test",
            categoryId: "test",
            videos: nil,
            synonyms: nil
        )
        
        do {
            _ = try await sut.getVideoURL(for: signWithoutVideos)
            XCTFail("Должна быть выброшена ошибка для жеста без видео")
        } catch {
            XCTAssertTrue(error is VideoRepositoryError)
        }
    }
    
    // MARK: - Two-Level Caching Tests
    
    func testGetVideoURLForVideoWithShortTermCache() async throws {
        // Given
        let video = createMockVideo()
        mockNetworkMonitor.setConnected(true)
        
        // When
        let url = try await sut.getVideoURL(for: video, useFavoritesCache: false)
        
        // Then
        XCTAssertNotNil(url)
        // Краткосрочный кеш скачивает видео в tmp/ и возвращает локальный file URL
        XCTAssertTrue(url.isFileURL, "Краткосрочный кеш должен возвращать локальный file URL")
    }
    
    func testCachedVideoURLReturnsNilWhenNotCached() {
        // Given
        let video = createMockVideo()
        
        // When
        let cachedURL = sut.cachedVideoURL(for: video)
        
        // Then
        XCTAssertNil(cachedURL, "Должен возвращать nil, когда видео не кешировано")
    }
    
    func testCachedVideoURLReturnsCachedURLAfterLoad() async throws {
        // Given
        let video = createMockVideo()
        mockNetworkMonitor.setConnected(true)
        
        // Загружаем видео (попадёт в краткосрочный кеш)
        _ = try await sut.getVideoURL(for: video, useFavoritesCache: false)
        
        // When
        let cachedURL = sut.cachedVideoURL(for: video)
        
        // Then
        XCTAssertNotNil(cachedURL, "Должен возвращать URL после загрузки в кеш")
        XCTAssertTrue(cachedURL!.isFileURL, "Должен возвращать локальный file URL")
    }
    
    func testCachedVideoURLReturnsNilAfterClearCache() async throws {
        // Given
        let video = createMockVideo()
        mockNetworkMonitor.setConnected(true)
        _ = try await sut.getVideoURL(for: video, useFavoritesCache: false)
        
        // When
        sut.clearCache()
        let cachedURL = sut.cachedVideoURL(for: video)
        
        // Then
        XCTAssertNil(cachedURL, "После очистки кеша должен возвращать nil")
    }
    
    func testGetVideoURLForVideoWithNoInternetThrowsError() async {
        // Given
        let video = createMockVideo()
        mockNetworkMonitor.setConnected(false)
        
        // When/Then
        do {
            _ = try await sut.getVideoURL(for: video, useFavoritesCache: false)
            XCTFail("Должна быть выброшена ошибка noInternetConnection")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, VideoRepositoryError.noInternetConnection)
        } catch {
            XCTFail("Неожиданный тип ошибки: \(error)")
        }
    }
    
    func testGetVideoURLWithFavoritesCacheNoInternetThrowsVideoNotCached() async {
        // Given
        let video = createMockVideo()
        mockNetworkMonitor.setConnected(false)
        VideoCacheService().clearAllCache()
        
        // When/Then
        do {
            _ = try await sut.getVideoURL(for: video, useFavoritesCache: true)
            XCTFail("Должна быть выброшена ошибка videoNotCached")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, VideoRepositoryError.videoNotCached)
        } catch {
            XCTFail("Неожиданный тип ошибки: \(error)")
        }
    }
    
    func testGetVideoURLWithInvalidVideoURL() async {
        // Given
        let videoWithInvalidURL = SignVideo(
            id: 999,
            url: "not a valid url",
            contextDescription: "Invalid",
            order: 1,
            createdAt: nil,
            updatedAt: nil
        )
        
        // When/Then
        // Невалидный URL должен выбрасывать ошибку для обоих режимов кеширования
        do {
            _ = try await sut.getVideoURL(for: videoWithInvalidURL, useFavoritesCache: false)
            XCTFail("Должна быть выброшена ошибка invalidURL для краткосрочного кеша")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, VideoRepositoryError.invalidURL)
        } catch {
            XCTFail("Неожиданный тип ошибки: \(error)")
        }
        
        // Для favorites cache тоже должна быть ошибка invalidURL
        do {
            _ = try await sut.getVideoURL(for: videoWithInvalidURL, useFavoritesCache: true)
            XCTFail("Должна быть выброшена ошибка invalidURL для favorites cache")
        } catch let error as VideoRepositoryError {
            XCTAssertEqual(error, VideoRepositoryError.invalidURL)
        } catch {
            XCTFail("Неожиданный тип ошибки: \(error)")
        }
    }
    
    func testPreloadVideoWithFavoritesCache() async throws {
        // Given
        let video = createMockVideo()
        mockNetworkMonitor.setConnected(true)
        
        // When/Then - не должен крашиться
        // Примечание: реальная предзагрузка требует сетевого запроса,
        // что выходит за рамки unit-теста
        try await sut.preloadVideo(video: video, useFavoritesCache: true)
    }
}

