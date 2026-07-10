import XCTest
@testable import RussianSignLanguageDictionary

final class URLErrorClassifierTests: XCTestCase {
    func testNotConnectedToInternetMapsToNoInternet() {
        let outcome = URLErrorClassifier.classify(URLError(.notConnectedToInternet))
        XCTAssertEqual(outcome, .noInternet)
    }

    func testNetworkConnectionLostMapsToNoInternet() {
        let outcome = URLErrorClassifier.classify(URLError(.networkConnectionLost))
        XCTAssertEqual(outcome, .noInternet)
    }

    func testTimedOutMapsToUnavailable() {
        let outcome = URLErrorClassifier.classify(URLError(.timedOut))
        XCTAssertEqual(outcome, .unavailable)
    }

    func testCannotFindHostMapsToUnavailable() {
        let outcome = URLErrorClassifier.classify(URLError(.cannotFindHost))
        XCTAssertEqual(outcome, .unavailable)
    }

    func testUnknownURLErrorCodeFallsBackToUnavailable() {
        let outcome = URLErrorClassifier.classify(URLError(.badServerResponse))
        XCTAssertEqual(outcome, .unavailable)
    }
}
