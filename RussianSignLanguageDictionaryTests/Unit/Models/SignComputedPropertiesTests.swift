import XCTest
@testable import RussianSignLanguageDictionary

final class SignComputedPropertiesTests: XCTestCase {
    func testFirstVideoReturnsNilWhenVideosAreNil() {
        let sign = makeSign(videos: nil)

        XCTAssertNil(sign.firstVideo)
    }

    func testFirstVideoReturnsNilWhenVideosAreEmpty() {
        let sign = makeSign(videos: [])

        XCTAssertNil(sign.firstVideo)
    }

    func testFirstVideoReturnsFirstVideoWhenMultipleVideosExist() {
        let videos = [
            makeVideo(id: 1, url: "https://example.com/1.mp4"),
            makeVideo(id: 2, url: "https://example.com/2.mp4")
        ]
        let sign = makeSign(videos: videos)

        XCTAssertEqual(sign.firstVideo?.id, 1)
    }

    func testPrimaryVideoURLReturnsNilWhenVideosAreNil() {
        let sign = makeSign(videos: nil)

        XCTAssertNil(sign.primaryVideoURL)
    }

    func testPrimaryVideoURLReturnsNilWhenVideosAreEmpty() {
        let sign = makeSign(videos: [])

        XCTAssertNil(sign.primaryVideoURL)
    }

    func testPrimaryVideoURLReturnsURLOfFirstVideo() {
        let videos = [
            makeVideo(id: 1, url: "https://example.com/1.mp4"),
            makeVideo(id: 2, url: "https://example.com/2.mp4")
        ]
        let sign = makeSign(videos: videos)

        XCTAssertEqual(sign.primaryVideoURL, "https://example.com/1.mp4")
    }

    func testVideosArrayReturnsEmptyArrayWhenVideosAreNil() {
        let sign = makeSign(videos: nil)

        XCTAssertEqual(sign.videosArray, [])
    }

    func testVideosArrayReturnsEmptyArrayWhenVideosAreEmpty() {
        let sign = makeSign(videos: [])

        XCTAssertEqual(sign.videosArray, [])
    }

    func testVideosArrayReturnsOriginalVideos() {
        let videos = [
            makeVideo(id: 1, url: "https://example.com/1.mp4"),
            makeVideo(id: 2, url: "https://example.com/2.mp4")
        ]
        let sign = makeSign(videos: videos)

        XCTAssertEqual(sign.videosArray.map(\.id), [1, 2])
    }

    private func makeSign(videos: [SignVideo]?) -> Sign {
        Sign(
            id: "sign-1",
            word: "Привет",
            description: "Описание",
            categoryId: "greetings",
            videos: videos,
            synonyms: nil
        )
    }

    private func makeVideo(id: Int, url: String) -> SignVideo {
        SignVideo(
            id: id,
            url: url,
            contextDescription: "Видео \(id)",
            order: id,
            createdAt: nil,
            updatedAt: nil
        )
    }
}
