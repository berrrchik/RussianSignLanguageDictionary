import XCTest
@testable import RussianSignLanguageDictionary

final class ETagManagerTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var sut: ETagManager!

    override func setUp() {
        super.setUp()
        userDefaults = makeIsolatedUserDefaults()
        sut = ETagManager(userDefaults: userDefaults)
    }

    override func tearDown() {
        sut = nil
        userDefaults = nil
        super.tearDown()
    }

    func testNormalizeETagRemovesQuotesAndSuffix() {
        let normalized = sut.normalizeETag(#""1234567890abcdef1234567890abcdef:gzip""#)

        XCTAssertEqual(normalized, "1234567890abcdef1234567890abcdef")
    }

    func testNormalizeETagRemovesSingleQuotes() {
        let normalized = sut.normalizeETag("'1234567890abcdef1234567890abcdef'")

        XCTAssertEqual(normalized, "1234567890abcdef1234567890abcdef")
    }

    func testSaveETagStoresNormalizedValueWithLength32() {
        let saved = sut.saveETag(#""1234567890abcdef1234567890abcdef:deflate""#, for: .syncData)

        XCTAssertTrue(saved)
        XCTAssertEqual(sut.getETag(for: .syncData), "1234567890abcdef1234567890abcdef")
    }

    func testSaveETagRejectsInvalidLength() {
        let saved = sut.saveETag(#""short-etag""#, for: .syncData)

        XCTAssertFalse(saved)
        XCTAssertNil(sut.getETag(for: .syncData))
    }

    func testRemoveETagDeletesStoredValue() {
        sut.saveETag(#""1234567890abcdef1234567890abcdef""#, for: .syncCheck)

        sut.removeETag(for: .syncCheck)

        XCTAssertNil(sut.getETag(for: .syncCheck))
    }
}
