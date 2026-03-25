import XCTest
@testable import RussianSignLanguageDictionary

final class FileCacheLRUTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = try createTemporaryDirectory()
    }

    override func tearDown() {
        tempDirectory = nil
        super.tearDown()
    }

    func testEnforceSizeLimitNoOpWhenBelowLimit() throws {
        try createFile(named: "a.mp4", size: 4, modifiedAt: .now)

        let removed = FileCacheLRU.enforceSizeLimit(at: tempDirectory, maxSize: 5)

        XCTAssertEqual(removed, 0)
        XCTAssertEqual(contentsCount(), 1)
    }

    func testEnforceSizeLimitNoOpWhenExactlyAtLimit() throws {
        try createFile(named: "a.mp4", size: 5, modifiedAt: .now)

        let removed = FileCacheLRU.enforceSizeLimit(at: tempDirectory, maxSize: 5)

        XCTAssertEqual(removed, 0)
        XCTAssertEqual(contentsCount(), 1)
    }

    func testEnforceSizeLimitRemovesOldestWhenOverflowedByOneByte() throws {
        try createFile(named: "old.mp4", size: 3, modifiedAt: Date(timeIntervalSince1970: 10))
        try createFile(named: "new.mp4", size: 3, modifiedAt: Date(timeIntervalSince1970: 20))

        let removed = FileCacheLRU.enforceSizeLimit(at: tempDirectory, maxSize: 5)

        XCTAssertEqual(removed, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("old.mp4").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("new.mp4").path))
    }

    func testEnforceSizeLimitCleansUntilTargetSize() throws {
        try createFile(named: "old.mp4", size: 4, modifiedAt: Date(timeIntervalSince1970: 10))
        try createFile(named: "mid.mp4", size: 4, modifiedAt: Date(timeIntervalSince1970: 20))
        try createFile(named: "new.mp4", size: 4, modifiedAt: Date(timeIntervalSince1970: 30))

        let removed = FileCacheLRU.enforceSizeLimit(at: tempDirectory, maxSize: 10, targetPercent: 50)

        XCTAssertEqual(removed, 2)
        XCTAssertEqual(currentSize(), 4)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory.appendingPathComponent("new.mp4").path))
    }

    func testEnforceSizeLimitReturnsZeroForEmptyDirectory() {
        XCTAssertEqual(FileCacheLRU.enforceSizeLimit(at: tempDirectory, maxSize: 1), 0)
    }

    private func createFile(named name: String, size: Int, modifiedAt date: Date) throws {
        let fileURL = tempDirectory.appendingPathComponent(name)
        try Data(repeating: 0x41, count: size).write(to: fileURL)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: fileURL.path)
    }

    private func contentsCount() -> Int {
        ((try? FileManager.default.contentsOfDirectory(atPath: tempDirectory.path)) ?? []).count
    }

    private func currentSize() -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []

        return files.reduce(0) { partialResult, url in
            partialResult + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }
}
