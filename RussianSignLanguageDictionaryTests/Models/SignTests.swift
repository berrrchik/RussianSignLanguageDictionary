import XCTest
@testable import RussianSignLanguageDictionary

final class SignTests: XCTestCase {
    
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
    
    // MARK: - Tests
    
    func testSignInitialization() {
        let sign = createMockSign()
        
        XCTAssertEqual(sign.id, "sign_001")
        XCTAssertEqual(sign.word, "Привет")
        XCTAssertEqual(sign.description, "Приветствие")
        XCTAssertEqual(sign.categoryId, "emotions")
        XCTAssertNotNil(sign.videos)
        XCTAssertEqual(sign.videos?.count, 1)
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
        XCTAssertEqual(sign.categoryId, decodedSign.categoryId)
        XCTAssertEqual(sign.videos?.first?.url, decodedSign.videos?.first?.url)
    }
    
    func testSignDecodingFromSnakeCase() throws {
        // JSON в snake_case формате (как приходит с сервера)
        let json = """
        {
            "id": "sign_001",
            "word": "Привет",
            "description": "Приветствие",
            "category_id": "emotions",
            "videos": [
                {
                    "id": 1,
                    "url": "https://lesulvngqpvgepijazin.supabase.co/storage/v1/object/public/signs/emotions/video_001.mp4",
                    "context_description": "Основное видео",
                    "order": 0
                }
            ]
        }
        """.data(using: .utf8)!
        
        // Декодирование с convertFromSnakeCase (автоматическая конвертация snake_case -> camelCase)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let sign = try decoder.decode(Sign.self, from: json)
        
        XCTAssertEqual(sign.id, "sign_001")
        XCTAssertEqual(sign.word, "Привет")
        XCTAssertNotNil(sign.videos)
        XCTAssertEqual(sign.videos?.first?.id, 1)
        XCTAssertEqual(sign.videos?.first?.url, "https://lesulvngqpvgepijazin.supabase.co/storage/v1/object/public/signs/emotions/video_001.mp4")
    }
}

