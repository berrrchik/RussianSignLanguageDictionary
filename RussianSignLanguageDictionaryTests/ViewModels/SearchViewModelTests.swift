import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class SearchViewModelTests: XCTestCase {
    var sut: SearchViewModel!
    var mockRepository: MockSignRepository!
    var mockNetworkMonitor: MockNetworkMonitor!
    var mockCategoryService: MockCategoryService!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockSignRepository()
        mockNetworkMonitor = MockNetworkMonitor()
        mockCategoryService = MockCategoryService()
        sut = SearchViewModel(
            signRepository: mockRepository,
            networkMonitor: mockNetworkMonitor,
            categoryService: mockCategoryService
        )
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        mockNetworkMonitor = nil
        mockCategoryService = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        XCTAssertEqual(sut.searchQuery, "")
        XCTAssertEqual(sut.searchResults, [])
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    // MARK: - Search Tests
    
    func testSearchWithEmptyQuery_ReturnsEmptyResults() async {
        // Given
        let emptyQuery = ""
        
        // When
        await sut.performSearch(query: emptyQuery)
        
        // Then
        XCTAssertEqual(sut.searchResults, [])
        XCTAssertFalse(sut.isLoading)
    }
    
    func testSearchWithValidQuery_ReturnsResults() async {
        // Given
        let query = "привет"
        let mockSigns = [
            Sign.mockWithWord("Привет"),
            Sign.mockWithWord("Приветствие")
        ]
        mockRepository.mockSigns = mockSigns
        
        // When
        await sut.loadAllSigns()
        await sut.performSearch(query: query)
        
        // Then
        XCTAssertEqual(sut.searchResults.count, 2)
        XCTAssertEqual(sut.searchResults[0].word, "Привет")
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testSearchWithError_SetsErrorMessage() async {
        // Given
        mockRepository.shouldFail = true
        mockRepository.errorToThrow = .fileNotFound
        
        // When
        await sut.loadAllSigns()
        
        // Then
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testSearchSetsLoadingState() async {
        // Given
        let query = "привет"
        let mockSigns = [
            Sign.mockWithWord("Привет"),
            Sign.mockWithWord("Приветствие")
        ]
        mockRepository.mockSigns = mockSigns
        
        // Загружаем данные сначала
        await sut.loadAllSigns()
        
        // When
        let searchTask = Task {
            await sut.performSearch(query: query)
        }
        
        // Then (проверяем loading state во время поиска)
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 сек
        XCTAssertTrue(sut.isLoading)
        
        await searchTask.value
        XCTAssertFalse(sut.isLoading)
    }
}

// MARK: - Sign Mock Helpers

extension Sign {
    static func mockWithWord(_ word: String) -> Sign {
        Sign(
            id: UUID().uuidString,
            word: word,
            description: "Описание для \(word)",
            categoryId: "test",
            videos: [
                SignVideo(
                    id: 1,
                    url: "https://example.com/\(word).mp4",
                    contextDescription: "Основное видео",
                    order: 0,
                    createdAt: nil,
                    updatedAt: nil
                )
            ],
            synonyms: nil
        )
    }
}

