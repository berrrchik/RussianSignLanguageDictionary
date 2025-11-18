import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class CategoriesViewModelTests: XCTestCase {
    var sut: CategoriesViewModel!
    var mockRepository: MockCategoriesSignRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockCategoriesSignRepository()
        sut = CategoriesViewModel(signRepository: mockRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        XCTAssertEqual(sut.categories, [])
        XCTAssertEqual(sut.state, .idle)
    }
    
    // MARK: - Load Categories Tests
    
    func testLoadCategories_Success() async {
        // Given
        let mockCategories = [
            Category.mock(id: "alphabet", name: "Алфавит", order: 1),
            Category.mock(id: "animals", name: "Животные", order: 2)
        ]
        mockRepository.categories = mockCategories
        
        // When
        await sut.loadCategories()
        
        // Then
        XCTAssertEqual(sut.categories.count, 2)
        XCTAssertEqual(sut.categories[0].name, "Алфавит")
        XCTAssertEqual(sut.state, .loaded)
    }
    
    func testLoadCategories_SortsByOrder() async {
        // Given
        let mockCategories = [
            Category.mock(id: "animals", name: "Животные", order: 2),
            Category.mock(id: "alphabet", name: "Алфавит", order: 1)
        ]
        mockRepository.categories = mockCategories
        
        // When
        await sut.loadCategories()
        
        // Then
        XCTAssertEqual(sut.categories[0].order, 1)
        XCTAssertEqual(sut.categories[1].order, 2)
    }
    
    func testLoadCategories_Error() async {
        // Given
        mockRepository.shouldThrowError = true
        
        // When
        await sut.loadCategories()
        
        // Then
        XCTAssertTrue(sut.categories.isEmpty)
        
        if case .error(let message) = sut.state {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected error state")
        }
    }
    
    func testLoadCategories_SetsLoadingState() async {
        // Given
        mockRepository.loadDelay = 0.3
        
        // When
        let task = Task {
            await sut.loadCategories()
        }
        
        // Then (проверяем loading state)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sut.state, .loading)
        
        await task.value
        XCTAssertEqual(sut.state, .loaded)
    }
}

// MARK: - Mock SignRepository

class MockCategoriesSignRepository: SignRepositoryProtocol {
    var categories: [RussianSignLanguageDictionary.Category] = []
    var shouldThrowError = false
    var loadDelay: TimeInterval = 0
    
    func loadAllSigns() async throws -> [Sign] {
        if shouldThrowError {
            throw SignRepositoryError.fileNotFound
        }
        return []
    }
    
    func loadCategories() async throws -> [RussianSignLanguageDictionary.Category] {
        if shouldThrowError {
            throw SignRepositoryError.fileNotFound
        }
        
        if loadDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(loadDelay * 1_000_000_000))
        }
        
        return categories
    }
    
    func getSign(byId id: String) async throws -> Sign? {
        return nil
    }
    
    func getSigns(byCategory categoryId: String) async throws -> [Sign] {
        return []
    }
    
    func searchSigns(query: String) async throws -> [Sign] {
        return []
    }
}

// MARK: - Category Mock Helper

extension RussianSignLanguageDictionary.Category {
    static func mock(id: String, name: String, order: Int) -> RussianSignLanguageDictionary.Category {
        RussianSignLanguageDictionary.Category(
            id: id,
            name: name,
            order: order,
            signCount: 10,
            icon: nil,
            color: nil
        )
    }
}

