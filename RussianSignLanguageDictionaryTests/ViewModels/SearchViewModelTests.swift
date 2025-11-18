import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class SearchViewModelTests: XCTestCase {
    var sut: SearchViewModel!
    var mockRepository: MockSignRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockSignRepository()
        sut = SearchViewModel(signRepository: mockRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
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
        mockRepository.searchResults = mockSigns
        
        // When
        await sut.performSearch(query: query)
        
        // Then
        XCTAssertEqual(sut.searchResults.count, 2)
        XCTAssertEqual(sut.searchResults[0].word, "Привет")
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testSearchWithError_SetsErrorMessage() async {
        // Given
        let query = "test"
        mockRepository.shouldThrowError = true
        
        // When
        await sut.performSearch(query: query)
        
        // Then
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testSearchSetsLoadingState() async {
        // Given
        let query = "привет"
        mockRepository.searchDelay = 0.5
        
        // When
        let searchTask = Task {
            await sut.performSearch(query: query)
        }
        
        // Then (проверяем loading state во время поиска)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 сек
        XCTAssertTrue(sut.isLoading)
        
        await searchTask.value
        XCTAssertFalse(sut.isLoading)
    }
}

// MARK: - Mock SignRepository

class MockSignRepository: SignRepositoryProtocol {
    var searchResults: [Sign] = []
    var shouldThrowError = false
    var searchDelay: TimeInterval = 0
    
    func loadAllSigns() async throws -> [Sign] {
        if shouldThrowError {
            throw SignRepositoryError.fileNotFound
        }
        return searchResults
    }
    
    func loadCategories() async throws -> [RussianSignLanguageDictionary.Category] {
        return []
    }
    
    func getSign(byId id: String) async throws -> Sign? {
        return searchResults.first { $0.id == id }
    }
    
    func getSigns(byCategory categoryId: String) async throws -> [Sign] {
        return searchResults.filter { $0.category == categoryId }
    }
    
    func searchSigns(query: String) async throws -> [Sign] {
        if shouldThrowError {
            throw SignRepositoryError.fileNotFound
        }
        
        if searchDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(searchDelay * 1_000_000_000))
        }
        
        return searchResults.filter { sign in
            sign.word.localizedCaseInsensitiveContains(query) ||
            sign.keywords.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
}

// MARK: - Sign Mock Helpers

extension Sign {
    static func mockWithWord(_ word: String) -> Sign {
        Sign(
            id: UUID().uuidString,
            word: word,
            description: "Описание для \(word)",
            category: "test",
            videoId: "video_\(word)",
            supabaseStoragePath: "test/path.mp4",
            supabaseUrl: "https://example.com/\(word).mp4",
            keywords: [word.lowercased()],
            embeddings: [],
            metadata: SignMetadata(
                duration: 3.0,
                fileSize: 500000,
                resolution: "1080x1920",
                format: "mp4",
                fps: 30
            )
        )
    }
}

