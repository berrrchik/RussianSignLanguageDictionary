import Combine
import XCTest

enum PublisherTestError: Error {
    case completedWithoutValue
    case timedOut
}

extension XCTestCase {
    func awaitPublisherValue<P: Publisher>(
        _ publisher: P,
        timeout: TimeInterval = 1.0,
        dropFirst valueCountToDrop: Int = 0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> P.Output {
        var receivedValue: P.Output?
        var receivedError: Error?
        var remainingValuesToDrop = valueCountToDrop

        let expectation = expectation(description: "Awaiting publisher value")

        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    receivedError = error
                    expectation.fulfill()
                } else if receivedValue == nil {
                    expectation.fulfill()
                }
            },
            receiveValue: { value in
                if remainingValuesToDrop > 0 {
                    remainingValuesToDrop -= 1
                    return
                }

                receivedValue = value
                expectation.fulfill()
            }
        )

        defer {
            cancellable.cancel()
        }

        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)

        switch result {
        case .completed:
            if let receivedError {
                throw receivedError
            }

            guard let receivedValue else {
                throw PublisherTestError.completedWithoutValue
            }

            return receivedValue
        default:
            XCTFail("Timed out while waiting for publisher value", file: file, line: line)
            throw PublisherTestError.timedOut
        }
    }

    func collectPublisherValues<P: Publisher>(
        _ publisher: P,
        count: Int,
        timeout: TimeInterval = 1.0,
        dropFirst valueCountToDrop: Int = 0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [P.Output] {
        precondition(count > 0, "count must be greater than zero")

        var receivedValues: [P.Output] = []
        var receivedError: Error?
        var remainingValuesToDrop = valueCountToDrop

        let expectation = expectation(description: "Collecting publisher values")

        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    receivedError = error
                    expectation.fulfill()
                }
            },
            receiveValue: { value in
                if remainingValuesToDrop > 0 {
                    remainingValuesToDrop -= 1
                    return
                }

                receivedValues.append(value)
                if receivedValues.count == count {
                    expectation.fulfill()
                }
            }
        )

        defer {
            cancellable.cancel()
        }

        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)

        switch result {
        case .completed:
            if let receivedError {
                throw receivedError
            }

            return receivedValues
        default:
            XCTFail("Timed out while collecting publisher values", file: file, line: line)
            throw PublisherTestError.timedOut
        }
    }
}
