import XCTest
@testable import RussianSignLanguageDictionary

final class VideoCacheDirectoryManagerTests: XCTestCase {
    private var tempDirectory: URL!
    private var sut: VideoCacheDirectoryManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = try createTemporaryDirectory()
        sut = VideoCacheDirectoryManager(cacheDirectory: tempDirectory)
    }

    override func tearDown() {
        sut = nil
        tempDirectory = nil
        super.tearDown()
    }

    func testVideoIdIsStableForSameURL() {
        let url = URL(string: "https://example.com/video.mp4")!

        XCTAssertEqual(sut.videoId(from: url), sut.videoId(from: url))
    }

    func testVideoIdDiffersForDifferentURLs() {
        let first = URL(string: "https://example.com/video-1.mp4")!
        let second = URL(string: "https://example.com/video-2.mp4")!

        XCTAssertNotEqual(sut.videoId(from: first), sut.videoId(from: second))
    }

    func testVideoIdUsesFirst16HexCharacters() {
        let id = sut.videoId(from: URL(string: "https://example.com/video.mp4")!)

        XCTAssertEqual(id.count, 16)
        XCTAssertTrue(id.allSatisfy { $0.isHexDigit })
    }

    func testCacheFileURLUsesProvidedDirectory() throws {
        let fileURL = try XCTUnwrap(sut.cacheFileURL(for: "abc123"))

        XCTAssertEqual(fileURL.deletingLastPathComponent(), tempDirectory)
        XCTAssertEqual(fileURL.lastPathComponent, "abc123.mp4")
    }

    func testFileExistsHelpersReflectWrittenFile() throws {
        let fileURL = tempDirectory.appendingPathComponent("sample.mp4")
        try Data("video".utf8).write(to: fileURL)

        XCTAssertTrue(sut.fileExists(at: fileURL))
        XCTAssertTrue(sut.fileExists(atPath: fileURL.path))
    }

    func testGetCacheSizeReturnsZeroForEmptyDirectory() {
        XCTAssertEqual(sut.getCacheSize(), 0)
    }

    func testGetCacheSizeSumsFileSizes() throws {
        try writeFile(named: "first.mp4", size: 3)
        try writeFile(named: "second.mp4", size: 5)

        XCTAssertEqual(sut.getCacheSize(), 8)
    }

    func testRemoveItemDeletesFile() throws {
        let fileURL = try writeFile(named: "to-remove.mp4", size: 1)

        try sut.removeItem(at: fileURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testRemoveFileDeletesMatchingCachedVideo() async throws {
        let originalURL = URL(string: "https://example.com/video.mp4")!
        let fileURL = try XCTUnwrap(sut.cacheFileURL(for: sut.videoId(from: originalURL)))
        try Data("video".utf8).write(to: fileURL)

        sut.removeFile(for: originalURL)

        let removed = await waitUntil {
            !FileManager.default.fileExists(atPath: fileURL.path)
        }
        XCTAssertTrue(removed)
    }

    func testClearAllCacheRemovesAllFiles() async throws {
        try writeFile(named: "first.mp4", size: 1)
        try writeFile(named: "second.mp4", size: 1)

        sut.clearAllCache()

        let cleared = await waitUntil {
            ((try? FileManager.default.contentsOfDirectory(atPath: self.tempDirectory.path)) ?? []).isEmpty
        }
        XCTAssertTrue(cleared)
    }

    private func writeFile(named name: String, size: Int) throws -> URL {
        let url = tempDirectory.appendingPathComponent(name)
        try Data(repeating: 0x41, count: size).write(to: url)
        return url
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollInterval: UInt64 = 20_000_000,
        condition: @escaping () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return true
            }

            try? await Task.sleep(nanoseconds: pollInterval)
        }

        return condition()
    }
}
