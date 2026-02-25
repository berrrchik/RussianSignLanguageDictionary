import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class CategoriesViewModelTests: XCTestCase {
    var sut: CategoriesViewModel!
    var mockRepository: MockSignRepository!
    var mockNetworkMonitor: MockNetworkMonitor!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockSignRepository()
        mockNetworkMonitor = MockNetworkMonitor()
        sut = CategoriesViewModel(
            signRepository: mockRepository,
            networkMonitor: mockNetworkMonitor
        )
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        mockNetworkMonitor = nil
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
        mockRepository.mockCategories = mockCategories
        
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
        mockRepository.mockCategories = mockCategories
        
        // When
        await sut.loadCategories()
        
        // Then
        XCTAssertEqual(sut.categories[0].order, 1)
        XCTAssertEqual(sut.categories[1].order, 2)
    }
    
    func testLoadCategories_Error() async {
        // Given
        mockRepository.shouldFail = true
        mockRepository.errorToThrow = .fileNotFound
        
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
        let mockCategories = [
            Category.mock(id: "alphabet", name: "Алфавит", order: 1)
        ]
        mockRepository.mockCategories = mockCategories
        
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

