import Foundation
@testable import RussianSignLanguageDictionary

final class VideoCacheServiceFake: VideoCacheServiceProtocol {
    private var cachedVideos: [String: URL]

    init(cachedVideos: [String: URL] = [:]) {
        self.cachedVideos = cachedVideos
    }

    func isVideoCached(_ video: SignVideo) -> Bool {
        cachedVideos[video.url] != nil
    }

    func isVideoCached(url: URL) -> Bool {
        cachedVideos[url.absoluteString] != nil
    }

    func getCachedVideoURL(_ video: SignVideo) -> URL? {
        cachedVideos[video.url]
    }

    func getCachedVideoURL(originalURL: URL) -> URL? {
        cachedVideos[originalURL.absoluteString]
    }

    func downloadAndCache(video: SignVideo) async throws -> URL {
        let localURL = URL(fileURLWithPath: "/tmp/fake-video-\(video.id).mp4")
        cachedVideos[video.url] = localURL
        return localURL
    }

    func downloadAndCache(url: URL) async throws -> URL {
        let localURL = URL(fileURLWithPath: "/tmp/\(url.lastPathComponent)")
        cachedVideos[url.absoluteString] = localURL
        return localURL
    }

    func preloadVideo(_ video: SignVideo) async {
        _ = try? await downloadAndCache(video: video)
    }

    func preloadVideos(_ videos: [SignVideo]) async {
        for video in videos {
            await preloadVideo(video)
        }
    }

    func clearCache(for video: SignVideo) {
        cachedVideos.removeValue(forKey: video.url)
    }

    func clearCache(for url: URL) {
        cachedVideos.removeValue(forKey: url.absoluteString)
    }

    func clearCache(for signId: String, videos: [SignVideo]) {
        for video in videos {
            cachedVideos.removeValue(forKey: video.url)
        }
    }

    func clearAllCache() {
        cachedVideos.removeAll()
    }

    func getCacheSize() -> Int {
        cachedVideos.count
    }

    func ensureCacheLimit() {}
}
