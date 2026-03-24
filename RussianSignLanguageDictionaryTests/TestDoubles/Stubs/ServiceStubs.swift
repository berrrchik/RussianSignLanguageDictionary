import Foundation
@testable import RussianSignLanguageDictionary

final class NetworkMonitorStub: NetworkMonitorProtocol {
    let connected: Bool

    init(connected: Bool) {
        self.connected = connected
    }

    func isConnected() -> Bool {
        connected
    }

    func checkConnection() async -> Bool {
        connected
    }
}

@MainActor
final class CategoryServiceStub: CategoryServiceProtocol {
    let categories: [AppCategory]

    init(categories: [AppCategory] = [TestFixtures.category]) {
        self.categories = categories
    }

    func loadCategories() async {}

    func name(for categoryId: String) -> String {
        categories.first(where: { $0.id == categoryId })?.name ?? categoryId
    }

    func category(for categoryId: String) -> AppCategory? {
        categories.first(where: { $0.id == categoryId })
    }

    func icon(for categoryId: String) -> String? {
        categories.first(where: { $0.id == categoryId })?.icon
    }

    func color(for categoryId: String) -> String? {
        categories.first(where: { $0.id == categoryId })?.color
    }

    func allCategories() -> [AppCategory] {
        categories
    }
}

final class VideoCacheServiceStub: VideoCacheServiceProtocol {
    let cachedURL: URL?
    let cacheSize: Int

    init(
        cachedURL: URL? = nil,
        cacheSize: Int = 0
    ) {
        self.cachedURL = cachedURL
        self.cacheSize = cacheSize
    }

    func isVideoCached(_ video: SignVideo) -> Bool {
        cachedURL != nil
    }

    func isVideoCached(url: URL) -> Bool {
        cachedURL != nil
    }

    func getCachedVideoURL(_ video: SignVideo) -> URL? {
        cachedURL
    }

    func getCachedVideoURL(originalURL: URL) -> URL? {
        cachedURL
    }

    func downloadAndCache(video: SignVideo) async throws -> URL {
        cachedURL ?? URL(fileURLWithPath: "/tmp/video-cache-stub.mp4")
    }

    func downloadAndCache(url: URL) async throws -> URL {
        cachedURL ?? URL(fileURLWithPath: "/tmp/url-cache-stub.mp4")
    }

    func preloadVideo(_ video: SignVideo) async {}

    func preloadVideos(_ videos: [SignVideo]) async {}

    func clearCache(for video: SignVideo) {}

    func clearCache(for url: URL) {}

    func clearCache(for signId: String, videos: [SignVideo]) {}

    func clearAllCache() {}

    func getCacheSize() -> Int {
        cacheSize
    }

    func ensureCacheLimit() {}
}
