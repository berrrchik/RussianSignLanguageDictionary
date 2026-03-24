import XCTest

final class RussianSignLanguageDictionaryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

        func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertEqual(app.state, .runningForeground)
    }
}
