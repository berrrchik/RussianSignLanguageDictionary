import XCTest
@testable import RussianSignLanguageDictionary

final class SignsDataTests: XCTestCase {
    
    // MARK: - Test Data
    
    private func createMockSignsData() -> SignsData {
        let sign = Sign(
            id: "sign_001",
            word: "Привет",
            description: "Приветствие",
            categoryId: "emotions",
            videos: [
                SignVideo(
                    id: 1,
                    url: "/signs/emotions/video_001.mp4",
                    contextDescription: "Основное видео",
                    order: 0,
                    createdAt: nil,
                    updatedAt: nil
                )
            ],
            synonyms: nil
        )
        
        let category = Category(
            id: "emotions",
            name: "Эмоции",
            order: 1,
            signCount: 1,
            icon: "face.smiling",
            color: "#FF9500",
            createdAt: nil,
            updatedAt: nil
        )
        
        return SignsData(
            signs: [sign],
            categories: [category],
            lessons: [],
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

