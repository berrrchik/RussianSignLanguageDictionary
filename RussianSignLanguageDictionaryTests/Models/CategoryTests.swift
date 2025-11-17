import XCTest
@testable import RussianSignLanguageDictionary

final class CategoryTests: XCTestCase {
    
    // MARK: - Test Data
    
    private func createMockCategory() -> RussianSignLanguageDictionary.Category {
        return RussianSignLanguageDictionary.Category(
            id: "emotions",
            name: "Эмоции",
            order: 1,
            signCount: 50,
            icon: "face.smiling",
            color: "#FF9500"
        )
    }
    
    // MARK: - Tests
    
    func testCategoryInitialization() {
        let category = createMockCategory()
        
        XCTAssertEqual(category.id, "emotions")
        XCTAssertEqual(category.name, "Эмоции")
        XCTAssertEqual(category.order, 1)
        XCTAssertEqual(category.signCount, 50)
        XCTAssertEqual(category.icon, "face.smiling")
        XCTAssertEqual(category.color, "#FF9500")
    }
    
    func testCategoryIdentifiable() {
        let category = createMockCategory()
        XCTAssertEqual(category.id, "emotions")
    }
    
    func testCategoryHashable() {
        let category1 = createMockCategory()
        let category2 = createMockCategory()
        
        XCTAssertEqual(category1, category2)
        XCTAssertEqual(category1.hashValue, category2.hashValue)
    }
    
    func testCategoryCodable() throws {
        let category = createMockCategory()
        
        // Кодирование
        let encoder = JSONEncoder()
        let data = try encoder.encode(category)
        
        // Декодирование
        let decoder = JSONDecoder()
        let decodedCategory = try decoder.decode(RussianSignLanguageDictionary.Category.self, from: data)
        
        XCTAssertEqual(category.id, decodedCategory.id)
        XCTAssertEqual(category.name, decodedCategory.name)
        XCTAssertEqual(category.order, decodedCategory.order)
        XCTAssertEqual(category.signCount, decodedCategory.signCount)
    }
}

