import Combine
import XCTest
@testable import RussianSignLanguageDictionary

final class TestInfrastructureHelpersTests: XCTestCase {
    func testMakeIsolatedUserDefaultsCreatesIndependentSuite() {
        let isolatedDefaults = makeIsolatedUserDefaults()

        isolatedDefaults.set("value", forKey: "sample-key")

        XCTAssertEqual(isolatedDefaults.string(forKey: "sample-key"), "value")
        XCTAssertNil(UserDefaults.standard.string(forKey: "sample-key"))
    }

    func testTemporaryDirectoryHelperCreatesWritableDirectory() throws {
        let directoryURL = try createTemporaryDirectory()
        let fileURL = directoryURL.appendingPathComponent("sample.txt")

        try "fixture".write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: directoryURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testAwaitPublisherValueReturnsNextPublishedValue() throws {
        let subject = PassthroughSubject<Int, Never>()

        DispatchQueue.main.async {
            subject.send(42)
        }

        let value = try awaitPublisherValue(subject.eraseToAnyPublisher())
        XCTAssertEqual(value, 42)
    }

    func testCollectPublisherValuesCollectsRequestedAmount() throws {
        let subject = PassthroughSubject<Int, Never>()

        DispatchQueue.main.async {
            subject.send(1)
            subject.send(2)
        }

        let values = try collectPublisherValues(subject.eraseToAnyPublisher(), count: 2)
        XCTAssertEqual(values, [1, 2])
    }

    func testWaitForDebouncedUpdateWaitsForConditionWithoutSleep() {
        let state = LockedFlag()

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            state.value = true
        }

        XCTAssertTrue(waitForDebouncedUpdate(interval: 0.05, timeout: 0.5) {
            state.value
        })
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = false

    var value: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
        set {
            lock.lock()
            storage = newValue
            lock.unlock()
        }
    }
}
