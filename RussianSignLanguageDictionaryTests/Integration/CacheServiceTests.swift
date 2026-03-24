import XCTest
@testable import RussianSignLanguageDictionary

final class CacheServiceTests: XCTestCase {
    private var sut: CacheService!
    private var cacheDirectoryURL: URL!

    override func setUp() {
        super.setUp()
        cacheDirectoryURL = try? createTemporaryDirectory()
        sut = CacheService(cacheDirectoryURL: cacheDirectoryURL)
    }

    override func tearDown() {
        try? sut?.clearCache()
        sut = nil
        cacheDirectoryURL = nil
        super.tearDown()
    }

    func testSaveAndLoadRoundTrip() throws {
        try sut.save(TestFixtures.syncData)

        let loaded = try sut.load()

        XCTAssertEqual(loaded?.signs.count, TestFixtures.syncData.signs.count)
        XCTAssertEqual(loaded?.categories.count, TestFixtures.syncData.categories.count)
    }

    func testHasCacheReflectsSaveAndClear() throws {
        XCTAssertFalse(sut.hasCache())

        try sut.save(TestFixtures.syncData)
        XCTAssertTrue(sut.hasCache())

        try sut.clearCache()
        XCTAssertFalse(sut.hasCache())
    }

    func testLoadReturnsNilWhenCacheFileIsMissing() throws {
        XCTAssertNil(try sut.load())
    }

    func testLoadThrowsForCorruptedJSON() throws {
        let cacheFileURL = cacheDirectoryURL.appendingPathComponent("cached_signs_data.json")
        try Data("bad-json".utf8).write(to: cacheFileURL)

        XCTAssertThrowsError(try sut.load()) { error in
            guard case .unableToLoad = error as? CacheError else {
                return XCTFail("Expected unableToLoad, got \(error)")
            }
        }
    }

    func testSaveThrowsForWriteError() throws {
        let invalidDirectoryURL = try createTemporaryDirectory(testName: "invalid-cache-path")
        let fileURL = invalidDirectoryURL.appendingPathComponent("occupied", isDirectory: false)
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())

        let invalidCacheService = CacheService(cacheDirectoryURL: fileURL)

        XCTAssertThrowsError(try invalidCacheService.save(TestFixtures.syncData)) { error in
            guard case .unableToSave = error as? CacheError else {
                return XCTFail("Expected unableToSave, got \(error)")
            }
        }
    }
}
