import XCTest
@testable import RussianSignLanguageDictionary

final class VideoRepositoryErrorTests: XCTestCase {
    func testFromVideoCacheErrorMapsAllKnownCases() {
        XCTAssertEqual(VideoRepositoryError.from(.invalidURL), .invalidURL)
        XCTAssertEqual(VideoRepositoryError.from(.noInternetConnection), .noInternetConnection)
        XCTAssertEqual(VideoRepositoryError.from(.fileNotFound), .noInternetConnection)
        XCTAssertEqual(VideoRepositoryError.from(.videoUnavailable), .videoUnavailable)
        XCTAssertEqual(VideoRepositoryError.from(.cacheDirectoryNotAvailable), .videoUnavailable)
        XCTAssertEqual(VideoRepositoryError.from(.sessionNotConfigured), .videoUnavailable)
    }
}
