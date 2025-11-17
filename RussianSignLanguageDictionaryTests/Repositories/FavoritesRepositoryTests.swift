import XCTest
@testable import RussianSignLanguageDictionary

final class FavoritesRepositoryTests: XCTestCase {
    
    var sut: FavoritesRepository!
    var mockUserDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        
        // Создание тестового UserDefaults
        mockUserDefaults = UserDefaults(suiteName: "TestDefaults")!
        mockUserDefaults.removePersistentDomain(forName: "TestDefaults")
        
        sut = FavoritesRepository(userDefaults: mockUserDefaults)
    }
    
    override func tearDown() {
        sut?.clearAllFavorites()
        mockUserDefaults.removePersistentDomain(forName: "TestDefaults")
        sut = nil
        mockUserDefaults = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testGetFavoritesInitiallyEmpty() {
        let favorites = sut.getFavorites()
        
        XCTAssertTrue(favorites.isEmpty, "Изначально избранное должно быть пустым")
    }
    
    func testAddFavorite() {
        let signId = "sign_001"
        
        sut.addFavorite(signId: signId)
        let favorites = sut.getFavorites()
        
        XCTAssertEqual(favorites.count, 1)
        XCTAssertTrue(favorites.contains(signId))
    }
    
    func testAddMultipleFavorites() {
        let signIds = ["sign_001", "sign_002", "sign_003"]
        
        signIds.forEach { sut.addFavorite(signId: $0) }
        let favorites = sut.getFavorites()
        
        XCTAssertEqual(favorites.count, 3)
        signIds.forEach { XCTAssertTrue(favorites.contains($0)) }
    }
    
    func testAddDuplicateFavorite() {
        let signId = "sign_001"
        sut.addFavorite(signId: signId)
        
        sut.addFavorite(signId: signId)
        let favorites = sut.getFavorites()
        
        XCTAssertEqual(favorites.count, 1, "Дубликаты не должны добавляться")
    }
    
    func testRemoveFavorite() {
        let signId = "sign_001"
        sut.addFavorite(signId: signId)
        
        sut.removeFavorite(signId: signId)
        let favorites = sut.getFavorites()
        
        XCTAssertTrue(favorites.isEmpty)
        XCTAssertFalse(favorites.contains(signId))
    }
    
    func testRemoveNonExistentFavorite() {
        let signId = "sign_001"
        sut.addFavorite(signId: signId)
        
        sut.removeFavorite(signId: "sign_002")
        let favorites = sut.getFavorites()
        
        XCTAssertEqual(favorites.count, 1)
        XCTAssertTrue(favorites.contains(signId))
    }
    
    func testIsFavorite() {
        let signId = "sign_001"
        sut.addFavorite(signId: signId)
        
        XCTAssertTrue(sut.isFavorite(signId: signId))
        XCTAssertFalse(sut.isFavorite(signId: "sign_002"))
    }
    
    func testClearAllFavorites() {
        ["sign_001", "sign_002", "sign_003"].forEach { sut.addFavorite(signId: $0) }
        
        sut.clearAllFavorites()
        let favorites = sut.getFavorites()
        
        XCTAssertTrue(favorites.isEmpty)
    }
    
    func testFavoritesPublisher() {
        let expectation = XCTestExpectation(description: "Publisher должен обновиться")
        let signId = "sign_001"
        
        var receivedFavorites: [String] = []
        let cancellable = sut.$favoritesPublisher.sink { favorites in
            receivedFavorites = favorites
            if favorites.contains(signId) {
                expectation.fulfill()
            }
        }
        
        sut.addFavorite(signId: signId)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(receivedFavorites.contains(signId))
        
        cancellable.cancel()
    }
    
    func testPersistence() {
        let signId = "sign_001"
        sut.addFavorite(signId: signId)
        
        let newRepository = FavoritesRepository(userDefaults: mockUserDefaults)
        let favorites = newRepository.getFavorites()
        
        XCTAssertEqual(favorites.count, 1)
        XCTAssertTrue(favorites.contains(signId))
    }
}

