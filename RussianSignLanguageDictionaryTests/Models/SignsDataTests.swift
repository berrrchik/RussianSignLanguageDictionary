import XCTest
@testable import RussianSignLanguageDictionary

final class SignsDataTests: XCTestCase {
    
    // MARK: - Test Data
    
    private func createMockSignsData() -> SignsData {
        let metadata = SignMetadata(
            duration: 3.5,
            fileSize: 512000,
            resolution: "1080x1920",
            format: "mp4",
            fps: 30
        )
        
        let sign = Sign(
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
        
        let category = Category(
            id: "emotions",
            name: "Эмоции",
            order: 1,
            signCount: 1,
            icon: "face.smiling",
            color: "#FF9500"
        )
        
        return SignsData(
            signs: [sign],
            categories: [category],
            totalSigns: 1,
            totalCategories: 1,
            version: "1.0",
            lastUpdated: "2025-11-14"
        )
    }
    
    // MARK: - Tests
    
    func testSignsDataInitialization() {
        let signsData = createMockSignsData()
        
        XCTAssertEqual(signsData.signs.count, 1)
        XCTAssertEqual(signsData.categories.count, 1)
        XCTAssertEqual(signsData.totalSigns, 1)
        XCTAssertEqual(signsData.totalCategories, 1)
        XCTAssertEqual(signsData.version, "1.0")
        XCTAssertEqual(signsData.lastUpdated, "2025-11-14")
    }
    
    func testSignsDataCodable() throws {
        let signsData = createMockSignsData()
        
        // Кодирование
        let encoder = JSONEncoder()
        let data = try encoder.encode(signsData)
        
        // Декодирование
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SignsData.self, from: data)
        
        XCTAssertEqual(decoded.totalSigns, signsData.totalSigns)
        XCTAssertEqual(decoded.totalCategories, signsData.totalCategories)
        XCTAssertEqual(decoded.version, signsData.version)
        XCTAssertEqual(decoded.signs.count, signsData.signs.count)
    }
}

