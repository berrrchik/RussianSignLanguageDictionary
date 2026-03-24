import XCTest
@testable import RussianSignLanguageDictionary

/// Тесты для DataLoadCoordinator
final class DataLoadCoordinatorTests: XCTestCase {
    
    var sut: DataLoadCoordinator<String>!
    
    override func setUp() {
        super.setUp()
        sut = DataLoadCoordinator<String>(
            subsystem: "com.test",
            category: "DataLoadCoordinator"
        )
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testSingleTask() async throws {
        // Act
        let result = try await sut.getOrCreateTask {
            return "Success"
        }
        
        // Assert
        XCTAssertEqual(result, "Success")
    }
    
    func testTaskThrowsError() async {
        // Arrange
        enum TestError: Error {
            case testFailure
        }
        
        // Act & Assert
        do {
            _ = try await sut.getOrCreateTask {
                throw TestError.testFailure
            }
            XCTFail("Должна быть выброшена ошибка")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testParallelTasksPropagateSameErrorToAllWaiters() async {
        enum TestError: Error, Equatable {
            case failed
        }

        let firstTaskStarted = expectation(description: "first task started")
        let releaseFirstTask = expectation(description: "release first task")

        let firstTask = Task<Result<String, Error>, Never> {
            do {
                let value = try await sut.getOrCreateTask {
                    firstTaskStarted.fulfill()
                    await self.fulfillment(of: [releaseFirstTask], timeout: 1.0)
                    throw TestError.failed
                }
                return .success(value)
            } catch {
                return .failure(error)
            }
        }

        await fulfillment(of: [firstTaskStarted], timeout: 1.0)

        let secondTask = Task<Result<String, Error>, Never> {
            do {
                let value = try await sut.getOrCreateTask {
                    XCTFail("Second block should reuse the first task")
                    return "unexpected"
                }
                return .success(value)
            } catch {
                return .failure(error)
            }
        }

        releaseFirstTask.fulfill()
        let results = await [firstTask.value, secondTask.value]
        XCTAssertEqual(results.count, 2)

        for result in results {
            switch result {
            case .failure(let error as TestError):
                XCTAssertEqual(error, .failed)
            default:
                XCTFail("Expected TestError.failed")
            }
        }
    }
    
    func testParallelTasksReuseSameTask() async throws {
        // Arrange
        var executionCount = 0
        let executionCountLock = NSLock()
        
        // Act
        async let result1: String = sut.getOrCreateTask {
            executionCountLock.lock()
            executionCount += 1
            executionCountLock.unlock()
            
            // Симулируем долгую операцию
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            return "Result"
        }
        
        async let result2: String = sut.getOrCreateTask {
            executionCountLock.lock()
            executionCount += 1
            executionCountLock.unlock()
            
            try await Task.sleep(nanoseconds: 100_000_000)
            return "Result"
        }
        
        let results = try await [result1, result2]
        
        // Assert
        XCTAssertEqual(results[0], results[1])
        // Должна быть выполнена только одна задача, вторая ждёт результат первой
        XCTAssertEqual(executionCount, 1)
    }
    
    func testSequentialTasksExecuteSeparately() async throws {
        // Arrange
        var executionCount = 0
        
        // Act
        _ = try await sut.getOrCreateTask {
            executionCount += 1
            return "First"
        }
        
        // Ждём чтобы задача очистилась
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        _ = try await sut.getOrCreateTask {
            executionCount += 1
            return "Second"
        }
        
        // Assert
        XCTAssertEqual(executionCount, 2)
    }

    func testTaskResetsAfterError() async {
        enum TestError: Error {
            case failed
        }

        do {
            _ = try await sut.getOrCreateTask {
                throw TestError.failed
            }
            XCTFail("Expected failure")
        } catch {}

        do {
            let value = try await sut.getOrCreateTask {
                "Recovered"
            }
            XCTAssertEqual(value, "Recovered")
        } catch {
            XCTFail("Unexpected error after reset: \(error)")
        }
    }
    
    func testWithSyncDataType() async throws {
        // Arrange
        let coordinator = DataLoadCoordinator<SyncData>(
            subsystem: "com.test",
            category: "SyncData"
        )
        
        let testData = SyncData(
            categories: [],
            signs: [],
            lessons: [],
            lastUpdated: Date()
        )
        
        // Act
        let result = try await coordinator.getOrCreateTask {
            return testData
        }
        
        // Assert
        XCTAssertEqual(result.signs.count, 0)
        XCTAssertEqual(result.categories.count, 0)
        XCTAssertEqual(result.lessons.count, 0)
    }
}
