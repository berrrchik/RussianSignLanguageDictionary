import XCTest
@testable import RussianSignLanguageDictionary

final class VideoRepositoryTests: XCTestCase {
    
    var sut: VideoRepository!
    var mockNetworkMonitor: MockNetworkMonitor!
    
    override func setUp() {
        super.setUp()
        mockNetworkMonitor = MockNetworkMonitor()
        mockNetworkMonitor.setConnected(true)
        sut = VideoRepository(
            videoCacheService: VideoCacheService.shared,
            networkMonitor: mockNetworkMonitor
        )
    }
    
    override func tearDown() {
        sut?.clearCache()
        VideoCacheService.shared.clearAllCache()
        sut = nil
        mockNetworkMonitor = nil
        super.tearDown()
    }
    
    // MARK: - Test Data
    
    private func createMockSign() -> Sign {
        let metadata = SignMetadata(
            duration: 3.5,
            fileSize: 512000,
            resolution: "1080x1920",
            format: "mp4",
            fps: 30
        )
        
        return Sign(
            id: "sign_001",
            word: "Привет",
            description: "Приветствие",
            category: "emotions",
            videos: nil,
            synonyms: nil,
            embeddings: nil,
            videoId: "video_001",
            supabaseStoragePath: "signs/emotions/video_001.mp4",
            supabaseUrl: "https://lesulvngqpvgepijazin.supabase.co/storage/v1/object/public/signs/emotions/video_001.mp4",
            keywords: ["привет", "здравствуй"],
            metadata: metadata
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
        XCTAssertEqual(url.absoluteString, sign.supabaseUrl)
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
        let metadata = SignMetadata(duration: nil, fileSize: nil, resolution: nil, format: nil, fps: nil)
        let signWithInvalidURL = Sign(
            id: "sign_invalid",
            word: "Test",
            description: "Test",
            category: "test",
            videos: nil,
            synonyms: nil,
            embeddings: nil,
            videoId: "video_invalid",
            supabaseStoragePath: "invalid/path",
            supabaseUrl: "ht!tp://invalid url with spaces",
            keywords: [],
            metadata: metadata
        )
        
        do {
            _ = try await sut.getVideoURL(for: signWithInvalidURL)
            XCTFail("Должна быть выброшена ошибка для невалидного URL")
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
        XCTAssertEqual(url.absoluteString, video.url)
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
        VideoCacheService.shared.clearAllCache()
        
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
    
    func testGetVideoURLWithInvalidVideoURL() async throws {
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
        // Для краткосрочного кеша невалидный URL всё равно возвращается
        // (AVPlayer сам обработает ошибку при загрузке)
        let url = try await sut.getVideoURL(for: videoWithInvalidURL, useFavoritesCache: false)
        XCTAssertNotNil(url)
        
        // Для favorites cache должна быть ошибка invalidURL
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

