import XCTest
@testable import RussianSignLanguageDictionary

final class VideoSessionFactoryTests: XCTestCase {
    func testMakeSessionUsesShortVideoTimeouts() {
        let session = VideoSessionFactory.makeSession()

        XCTAssertEqual(session.configuration.timeoutIntervalForRequest, VideoSessionFactory.requestTimeout)
        XCTAssertEqual(session.configuration.timeoutIntervalForResource, VideoSessionFactory.resourceTimeout)
        XCTAssertFalse(session.configuration.waitsForConnectivity)
    }
}
