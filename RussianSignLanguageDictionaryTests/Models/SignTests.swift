import XCTest
@testable import RussianSignLanguageDictionary

final class SignTests: XCTestCase {
    
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
            keywords: ["привет", "здравствуй", "приветствие"],
            embeddings: [0.123, 0.456, 0.789],
            metadata: metadata
        )
    }
    
    // MARK: - Tests
    
    func testSignInitialization() {
        let sign = createMockSign()
        
        XCTAssertEqual(sign.id, "sign_001")
        XCTAssertEqual(sign.word, "Привет")
        XCTAssertEqual(sign.description, "Приветствие")
        XCTAssertEqual(sign.category, "emotions")
        XCTAssertEqual(sign.videoId, "video_001")
        XCTAssertEqual(sign.keywords.count, 3)
        XCTAssertEqual(sign.embeddings.count, 3)
    }
    
    func testSignIdentifiable() {
        let sign = createMockSign()
        XCTAssertEqual(sign.id, "sign_001")
    }
    
    func testSignHashable() {
        let sign1 = createMockSign()
        let sign2 = createMockSign()
        
        XCTAssertEqual(sign1, sign2)
        XCTAssertEqual(sign1.hashValue, sign2.hashValue)
    }
    
    func testSignCodable() throws {
        let sign = createMockSign()
        
        // Кодирование
        let encoder = JSONEncoder()
        let data = try encoder.encode(sign)
        
        // Декодирование
        let decoder = JSONDecoder()
        let decodedSign = try decoder.decode(Sign.self, from: data)
        
        XCTAssertEqual(sign.id, decodedSign.id)
        XCTAssertEqual(sign.word, decodedSign.word)
        XCTAssertEqual(sign.category, decodedSign.category)
        XCTAssertEqual(sign.supabaseUrl, decodedSign.supabaseUrl)
    }
    
    func testSignDecodingFromSnakeCase() throws {
        // JSON в snake_case формате (как в Bundle)
        let json = """
        {
            "id": "sign_001",
            "word": "Привет",
            "description": "Приветствие",
            "category": "emotions",
            "video_id": "video_001",
            "supabase_storage_path": "signs/emotions/video_001.mp4",
            "supabase_url": "https://lesulvngqpvgepijazin.supabase.co/storage/v1/object/public/signs/emotions/video_001.mp4",
            "keywords": ["привет", "здравствуй"],
            "embeddings": [0.123, 0.456],
            "metadata": {
                "duration": 3.5,
                "file_size": 512000,
                "resolution": "1080x1920",
                "format": "mp4",
                "fps": 30
            }
        }
        """.data(using: .utf8)!
        
        // Декодирование с convertFromSnakeCase (как в SignRepository)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let sign = try decoder.decode(Sign.self, from: json)
        
        XCTAssertEqual(sign.id, "sign_001")
        XCTAssertEqual(sign.word, "Привет")
        XCTAssertEqual(sign.videoId, "video_001")
        XCTAssertEqual(sign.supabaseUrl, "https://lesulvngqpvgepijazin.supabase.co/storage/v1/object/public/signs/emotions/video_001.mp4")
    }
}

