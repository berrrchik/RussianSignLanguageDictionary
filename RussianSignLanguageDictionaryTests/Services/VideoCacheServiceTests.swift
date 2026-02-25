import XCTest
@testable import RussianSignLanguageDictionary

final class VideoCacheServiceTests: XCTestCase {
    
    var sut: VideoCacheService!
    
    override func setUp() {
        super.setUp()
        sut = VideoCacheService()
        // Очищаем кеш перед каждым тестом
        sut.clearAllCache()
    }
    
    override func tearDown() {
        sut.clearAllCache()
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Test Data
    
    private func createMockVideo(id: Int = 1) -> SignVideo {
        return SignVideo(
            id: id,
            url: "https://example.com/video_\(id).mp4",
            contextDescription: "Test video \(id)",
            order: 1,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    // MARK: - Cache Size Tests
    
    func testGetCacheSizeInitiallyZero() {
        // Given - пустой кеш
        sut.clearAllCache()
        
        // When
        let size = sut.getCacheSize()
        
        // Then
        XCTAssertEqual(size, 0, "Размер пустого кеша должен быть 0")
    }
    
    // MARK: - Cache Checking Tests
    
    func testIsVideoCachedReturnsFalseForNotCachedVideo() {
        // Given
        let video = createMockVideo()
        sut.clearAllCache()
        
        // When
        let isCached = sut.isVideoCached(video)
        
        // Then
        XCTAssertFalse(isCached, "Видео не должно быть в кеше")
    }
    
    func testIsVideoCachedURLReturnsFalseForNotCachedURL() {
        // Given
        let url = URL(string: "https://example.com/test.mp4")!
        sut.clearAllCache()
        
        // When
        let isCached = sut.isVideoCached(url: url)
        
        // Then
        XCTAssertFalse(isCached, "URL не должен быть в кеше")
    }
    
    // MARK: - Get Cached Video URL Tests
    
    func testGetCachedVideoURLReturnsNilForNotCachedVideo() {
        // Given
        let video = createMockVideo()
        sut.clearAllCache()
        
        // When
        let cachedURL = sut.getCachedVideoURL(video)
        
        // Then
        XCTAssertNil(cachedURL, "URL кешированного видео должен быть nil для не кешированного видео")
    }
    
    // MARK: - Clear Cache Tests
    
    func testClearAllCache() {
        // Given/When
        sut.clearAllCache()
        
        // Then - если дошли сюда без крэша, тест прошёл
        XCTAssertEqual(sut.getCacheSize(), 0, "Кеш должен быть очищен")
    }
    
    func testClearCacheForVideo() {
        // Given
        let video = createMockVideo()
        
        // When
        sut.clearCache(for: video)
        
        // Ждём выполнения async операции
        let expectation = XCTestExpectation(description: "Cache cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then - если дошли сюда без крэша, тест прошёл
        XCTAssertFalse(sut.isVideoCached(video))
    }
    
    // MARK: - Video Invalid URL Tests
    
    func testIsVideoCachedReturnsFalseForInvalidURL() {
        // Given
        let videoWithInvalidURL = SignVideo(
            id: 999,
            url: "not a valid url",
            contextDescription: "Invalid",
            order: 1,
            createdAt: nil,
            updatedAt: nil
        )
        
        // When
        let isCached = sut.isVideoCached(videoWithInvalidURL)
        
        // Then
        XCTAssertFalse(isCached, "Видео с невалидным URL не должно быть в кеше")
    }
    
    // MARK: - Ensure Cache Limit Tests
    
    func testEnsureCacheLimitDoesNotCrash() {
        // Given/When - просто проверяем, что метод не крашится
        sut.ensureCacheLimit()
        
        // Then - если дошли сюда, тест прошёл
        XCTAssertTrue(true)
    }
    
    // MARK: - Clear Cache for Sign Tests
    
    func testClearCacheForSignWithVideos() {
        // Given
        let signId = "test-sign-id"
        let videos = [createMockVideo(id: 1), createMockVideo(id: 2)]
        
        // When
        sut.clearCache(for: signId, videos: videos)
        
        // Ждём выполнения async операции
        let expectation = XCTestExpectation(description: "Cache cleared for sign")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then - если дошли сюда без крэша, тест прошёл
        XCTAssertFalse(sut.isVideoCached(videos[0]))
        XCTAssertFalse(sut.isVideoCached(videos[1]))
    }
}
