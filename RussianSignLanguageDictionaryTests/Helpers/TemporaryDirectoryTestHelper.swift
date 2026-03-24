import Foundation
import XCTest

enum TemporaryDirectoryTestHelper {
    static func create(
        for testCase: XCTestCase,
        testName: String = #function,
        fileManager: FileManager = .default,
        cleanupOnTeardown: Bool = true
    ) throws -> URL {
        let directoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("RussianSignLanguageDictionaryTests", isDirectory: true)
            .appendingPathComponent("\(sanitize(testName))-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        if cleanupOnTeardown {
            testCase.addTeardownBlock {
                try? cleanup(at: directoryURL, fileManager: fileManager)
            }
        }

        return directoryURL
    }

    static func cleanup(at url: URL, fileManager: FileManager = .default) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    @discardableResult
    static func withTemporaryDirectory<T>(
        for testCase: XCTestCase,
        testName: String = #function,
        fileManager: FileManager = .default,
        perform work: (URL) throws -> T
    ) throws -> T {
        let directoryURL = try create(
            for: testCase,
            testName: testName,
            fileManager: fileManager,
            cleanupOnTeardown: false
        )

        defer {
            try? cleanup(at: directoryURL, fileManager: fileManager)
        }

        return try work(directoryURL)
    }

    private static func sanitize(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    }
}

extension XCTestCase {
    func createTemporaryDirectory(
        testName: String = #function,
        fileManager: FileManager = .default
    ) throws -> URL {
        try TemporaryDirectoryTestHelper.create(
            for: self,
            testName: testName,
            fileManager: fileManager
        )
    }

    @discardableResult
    func withTemporaryDirectory<T>(
        testName: String = #function,
        fileManager: FileManager = .default,
        perform work: (URL) throws -> T
    ) throws -> T {
        try TemporaryDirectoryTestHelper.withTemporaryDirectory(
            for: self,
            testName: testName,
            fileManager: fileManager,
            perform: work
        )
    }
}
