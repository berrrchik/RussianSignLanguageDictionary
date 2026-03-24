import XCTest
@testable import RussianSignLanguageDictionary

/// Тесты для MemoryCacheManager
final class MemoryCacheManagerTests: XCTestCase {
    
    var sut: MemoryCacheManager<String>!
    
    override func setUp() {
        super.setUp()
        sut = MemoryCacheManager<String>(label: "com.test.memoryCache")
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testInitiallyEmpty() {
        XCTAssertNil(sut.get())
        XCTAssertFalse(sut.hasData)
    }
    
    func testSetAndGet() {
        // Arrange
        let testData = "Test Data"
        
        // Act
        sut.set(testData)
        
        // Assert
        XCTAssertEqual(sut.get(), testData)
        XCTAssertTrue(sut.hasData)
    }
    
    func testClear() {
        // Arrange
        sut.set("Test Data")
        XCTAssertTrue(sut.hasData)
        
        // Act
        sut.clear()
        
        // Assert
        XCTAssertNil(sut.get())
        XCTAssertFalse(sut.hasData)
    }

    func testHasDataBecomesTrueAfterSetAndFalseAfterClear() {
        sut.set("Cached")
        XCTAssertTrue(sut.hasData)

        sut.clear()
        XCTAssertFalse(sut.hasData)
    }
    
    func testOverwrite() {
        // Arrange
        sut.set("First")
        
        // Act
        sut.set("Second")
        
        // Assert
        XCTAssertEqual(sut.get(), "Second")
    }
    
    func testThreadSafety() async {
        // Arrange
        let iterations = 1000
        
        // Act
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    self.sut.set("Value \(i)")
                }
                group.addTask {
                    _ = self.sut.get()
                }
            }
        }
        
        // Assert - не должно быть крашей
        XCTAssertTrue(sut.hasData)
    }

    func testConcurrentWritesKeepManagerOperational() async {
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<200 {
                group.addTask {
                    self.sut.set("Value \(index)")
                }
            }
        }

        XCTAssertNotNil(sut.get())
        XCTAssertTrue(sut.hasData)
    }
    
    func testWithComplexType() {
        // Arrange
        struct TestStruct: Equatable {
            let id: Int
            let name: String
        }
        
        let complexCache = MemoryCacheManager<TestStruct>(label: "com.test.complexCache")
        let testData = TestStruct(id: 1, name: "Test")
        
        // Act
        complexCache.set(testData)
        
        // Assert
        XCTAssertEqual(complexCache.get(), testData)
    }
}
