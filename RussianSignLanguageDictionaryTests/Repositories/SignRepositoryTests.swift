import XCTest
@testable import RussianSignLanguageDictionary

final class SignRepositoryTests: XCTestCase {
    
    var sut: SignRepository!
    
    override func setUp() {
        super.setUp()
        sut = SignRepository()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testLoadAllSigns() async throws {
        let signs = try await sut.loadAllSigns()
        
        XCTAssertFalse(signs.isEmpty, "Должны быть загружены жесты")
        XCTAssertEqual(signs.count, 996, "Должно быть 996 жестов")
    }
    
    func testLoadCategories() async throws {
        let categories = try await sut.loadCategories()
        
        XCTAssertFalse(categories.isEmpty, "Должны быть загружены категории")
        XCTAssertEqual(categories.count, 24, "Должно быть 24 категории")
        
        for i in 0..<categories.count - 1 {
            XCTAssertLessThanOrEqual(categories[i].order, categories[i + 1].order)
        }
    }
    
    func testGetSignById() async throws {
        let allSigns = try await sut.loadAllSigns()
        guard let firstSign = allSigns.first else {
            XCTFail("Нет жестов в данных")
            return
        }
        let testId = firstSign.id
        
        let sign = try await sut.getSign(byId: testId)
        
        XCTAssertNotNil(sign, "Жест должен быть найден")
        XCTAssertEqual(sign?.id, testId)
    }
    
    func testGetSignByIdNotFound() async throws {
        let nonExistentId = "non_existent_id_12345"
        
        let sign = try await sut.getSign(byId: nonExistentId)
        
        XCTAssertNil(sign, "Жест не должен быть найден")
    }
    
    func testGetSignsByCategory() async throws {
        let categories = try await sut.loadCategories()
        guard let firstCategory = categories.first else {
            XCTFail("Нет категорий в данных")
            return
        }
        let categoryId = firstCategory.id
        
        let signs = try await sut.getSigns(byCategory: categoryId)
        
        XCTAssertFalse(signs.isEmpty, "Должны быть жесты в категории")
        
        for sign in signs {
            XCTAssertEqual(sign.category, categoryId)
        }
    }
    
    func testSearchSigns() async throws {
        let query = "привет"
        
        let results = try await sut.searchSigns(query: query)
        
        XCTAssertFalse(results.isEmpty, "Должны быть найдены результаты")
        
        for sign in results {
            let containsInWord = sign.word.lowercased().contains(query.lowercased())
            let containsInKeywords = sign.keywords.contains { $0.lowercased().contains(query.lowercased()) }
            let containsInDescription = sign.description.lowercased().contains(query.lowercased())
            
            XCTAssertTrue(
                containsInWord || containsInKeywords || containsInDescription,
                "Жест должен содержать запрос в слове, ключевых словах или описании"
            )
        }
    }
    
    func testSearchSignsEmptyQuery() async throws {
        let query = ""
        
        let results = try await sut.searchSigns(query: query)
        
        XCTAssertTrue(results.isEmpty, "Пустой запрос должен вернуть пустой массив")
    }
    
    func testCaching() async throws {
        let signs1 = try await sut.loadAllSigns()
        
        let signs2 = try await sut.loadAllSigns()
        
        XCTAssertEqual(signs1.count, signs2.count)
    }
}

