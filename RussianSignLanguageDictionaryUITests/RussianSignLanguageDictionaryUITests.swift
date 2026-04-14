import XCTest

final class RussianSignLanguageDictionaryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5.0))
        XCTAssertEqual(app.state, .runningForeground)
    }
}
