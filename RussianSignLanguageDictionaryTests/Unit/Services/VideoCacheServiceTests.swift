import XCTest
@testable import RussianSignLanguageDictionary

final class VideoCacheServiceTests: XCTestCase {
    private var sut: VideoCacheService!
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = try createTemporaryDirectory()
        let manager = VideoCacheDirectoryManager(cacheDirectory: tempDirectory)
        let downloader = VideoCacheDownloader(
            directoryManager: manager,
            session: MockURLProtocol.makeEphemeralSession()
        )
        sut = VideoCacheService(directoryManager: manager, downloader: downloader)
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        sut = nil
        tempDirectory = nil
        super.tearDown()
    }

    func testIsVideoCachedReturnsFalseForInvalidURL() {
        XCTAssertFalse(sut.isVideoCached(makeVideo(url: "")))
        XCTAssertNil(sut.getCachedVideoURL(makeVideo(url: "")))
    }

    func testDownloadAndCacheStoresVideoForLookupByModelAndURL() async throws {
        let video = makeVideo()
        MockURLProtocol.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("video-data".utf8))
        }

        let localURL = try await sut.downloadAndCache(video: video)

        XCTAssertTrue(localURL.isFileURL)
        XCTAssertTrue(sut.isVideoCached(video))
        XCTAssertTrue(sut.isVideoCached(url: try XCTUnwrap(APIConfig.videoURL(forPath: video.url))))
        XCTAssertEqual(sut.getCachedVideoURL(video), localURL)
    }

    func testGetCachedVideoURLReturnsNilForMissingVideo() {
        XCTAssertNil(sut.getCachedVideoURL(makeVideo()))
        XCTAssertNil(sut.getCachedVideoURL(originalURL: URL(string: "https://example.com/missing.mp4")!))
    }

    func testClearCacheForSignRemovesAllCachedVideos() async throws {
        let first = makeVideo(id: 1, url: "/signs/test/one.mp4")
        let second = makeVideo(id: 2, url: "/signs/test/two.mp4")
        MockURLProtocol.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data((request.url?.absoluteString ?? "").utf8))
        }

        _ = try await sut.downloadAndCache(video: first)
        _ = try await sut.downloadAndCache(video: second)

        sut.clearCache(for: "sign-1", videos: [first, second])

        let cleared = await waitUntil {
            !self.sut.isVideoCached(first) && !self.sut.isVideoCached(second)
        }
        XCTAssertTrue(cleared)
    }

    func testClearAllCacheRemovesDownloadedFiles() async throws {
        let video = makeVideo()
        MockURLProtocol.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("video-data".utf8))
        }

        _ = try await sut.downloadAndCache(video: video)
        sut.clearAllCache()

        let cleared = await waitUntil {
            !self.sut.isVideoCached(video) && self.sut.getCacheSize() == 0
        }
        XCTAssertTrue(cleared)
    }

    func testGetCacheSizeReflectsDownloadedBytes() async throws {
        MockURLProtocol.setRequestHandler { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(repeating: 0x41, count: 7))
        }

        _ = try await sut.downloadAndCache(video: makeVideo())

        XCTAssertGreaterThanOrEqual(sut.getCacheSize(), 7)
    }

    func testEnsureCacheLimitDoesNotCrashOnEmptyCache() {
        sut.ensureCacheLimit()
        XCTAssertEqual(sut.getCacheSize(), 0)
    }

    private func makeVideo(id: Int = 1, url: String = "/signs/test/video_1.mp4") -> SignVideo {
        SignVideo(
            id: id,
            url: url,
            contextDescription: "Video \(id)",
            order: 1,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollInterval: UInt64 = 20_000_000,
        condition: @escaping () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return true
            }

            try? await Task.sleep(nanoseconds: pollInterval)
        }

        return condition()
    }
}
