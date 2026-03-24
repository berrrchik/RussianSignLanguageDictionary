import Foundation
import XCTest

enum UserDefaultsTestHelper {
    private static let lock = NSLock()
    private static var suiteNamesByIdentifier: [ObjectIdentifier: String] = [:]

    static func makeIsolatedUserDefaults(
        for testCase: XCTestCase,
        testName: String = #function,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> UserDefaults {
        let suiteName = [
            "RussianSignLanguageDictionaryTests",
            String(describing: type(of: testCase)),
            sanitize(testName),
            UUID().uuidString
        ].joined(separator: ".")

        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults for suite \(suiteName)", file: file, line: line)
            fatalError("Unable to create isolated UserDefaults")
        }

        register(userDefaults: userDefaults, suiteName: suiteName)
        cleanup(userDefaults: userDefaults)

        testCase.addTeardownBlock {
            cleanup(userDefaults: userDefaults)
        }

        return userDefaults
    }

    static func cleanup(userDefaults: UserDefaults) {
        lock.lock()
        let suiteName = suiteNamesByIdentifier[ObjectIdentifier(userDefaults)]
        lock.unlock()

        guard let suiteName else { return }
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults.synchronize()
    }

    private static func register(userDefaults: UserDefaults, suiteName: String) {
        lock.lock()
        suiteNamesByIdentifier[ObjectIdentifier(userDefaults)] = suiteName
        lock.unlock()
    }

    private static func sanitize(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    }
}

extension XCTestCase {
    func makeIsolatedUserDefaults(
        testName: String = #function,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> UserDefaults {
        UserDefaultsTestHelper.makeIsolatedUserDefaults(
            for: self,
            testName: testName,
            file: file,
            line: line
        )
    }
}
