import Foundation
import XCTest

extension XCTestCase {
    @discardableResult
    func waitForDebouncedUpdate(
        interval: TimeInterval,
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.01,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @escaping @Sendable () -> Bool
    ) -> Bool {
        let expectation = expectation(description: "Waiting for debounced update")
        let startDate = Date()

        let worker = DispatchQueue(label: "RussianSignLanguageDictionaryTests.waitForDebouncedUpdate")
        worker.async {
            while Date().timeIntervalSince(startDate) <= timeout {
                if Date().timeIntervalSince(startDate) >= interval, condition() {
                    expectation.fulfill()
                    return
                }

                Thread.sleep(forTimeInterval: pollInterval)
            }
        }

        let result = XCTWaiter().wait(for: [expectation], timeout: timeout + pollInterval)
        guard result == .completed else {
            XCTFail(
                "Timed out while waiting for debounced update after \(interval)s",
                file: file,
                line: line
            )
            return false
        }

        return true
    }
}
