import XCTest
@testable import RussianSignLanguageDictionary

final class LoggingSyncRepositoryDecoratorTests: XCTestCase {
    private var wrapped: SyncRepositorySpy!
    private var sut: LoggingSyncRepositoryDecorator!

    override func setUp() {
        super.setUp()
        wrapped = SyncRepositorySpy()
        sut = LoggingSyncRepositoryDecorator(wrapped: wrapped)
    }

    override func tearDown() {
        sut = nil
        wrapped = nil
        super.tearDown()
    }

    func testCheckForUpdatesDelegatesToWrappedAndReturnsItsResult() async throws {
        wrapped.checkForUpdatesResult = .success(TestFixtures.syncMetadata)

        let result = try await sut.checkForUpdates(lastUpdated: nil)

        XCTAssertEqual(wrapped.checkForUpdatesArguments.count, 1)
        XCTAssertEqual(result.hasUpdates, TestFixtures.syncMetadata.hasUpdates)
    }

    func testCheckForUpdatesPropagatesWrappedError() async {
        wrapped.checkForUpdatesResult = .failure(SyncError.noInternet)

        do {
            _ = try await sut.checkForUpdates(lastUpdated: nil)
            XCTFail("Expected error to propagate")
        } catch let error as SyncError {
            guard case .noInternet = error else {
                return XCTFail("Expected .noInternet, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchAllDataDelegatesToWrappedAndReturnsItsResult() async throws {
        wrapped.fetchAllDataResult = .success(TestFixtures.syncData)

        let result = try await sut.fetchAllData { TestFixtures.syncData }

        XCTAssertEqual(wrapped.fetchAllDataCallCount, 1)
        XCTAssertEqual(result.signs.count, TestFixtures.syncData.signs.count)
    }

    func testFetchAllDataPropagatesWrappedError() async {
        wrapped.fetchAllDataResult = .failure(SyncError.serverUnavailable)

        do {
            _ = try await sut.fetchAllData { TestFixtures.syncData }
            XCTFail("Expected error to propagate")
        } catch let error as SyncError {
            guard case .serverUnavailable = error else {
                return XCTFail("Expected .serverUnavailable, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
