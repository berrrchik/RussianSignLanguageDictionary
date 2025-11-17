import XCTest
@testable import RussianSignLanguageDictionary

final class VideoRepositoryTests: XCTestCase {
    
    var sut: VideoRepository!
    
    override func setUp() {
        super.setUp()
        sut = VideoRepository()
    }
    
    override func tearDown() {
        sut?.clearCache()
        sut = nil
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
            videoId: "video_001",
            supabaseStoragePath: "signs/emotions/video_001.mp4",
            supabaseUrl: "https://lesulvngqpvgepijazin.supabase.co/storage/v1/object/public/signs/emotions/video_001.mp4",
            keywords: ["привет", "здравствуй"],
            embeddings: [0.123, 0.456],
            metadata: metadata
        )
    }
    
    // MARK: - Tests
    
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
            videoId: "video_invalid",
            supabaseStoragePath: "invalid/path",
            supabaseUrl: "ht!tp://invalid url with spaces",
            keywords: [],
            embeddings: [],
            metadata: metadata
        )
        
        do {
            _ = try await sut.getVideoURL(for: signWithInvalidURL)
            XCTFail("Должна быть выброшена ошибка для невалидного URL")
        } catch {
            XCTAssertTrue(error is VideoRepositoryError)
        }
    }
}

