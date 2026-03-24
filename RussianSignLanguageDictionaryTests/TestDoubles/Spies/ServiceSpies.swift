import Foundation
@testable import RussianSignLanguageDictionary

final class NetworkMonitorSpy: NetworkMonitorProtocol {
    private(set) var isConnectedCallCount = 0
    private(set) var checkConnectionCallCount = 0

    var isConnectedValue = true
    var checkConnectionValue = true

    func isConnected() -> Bool {
        isConnectedCallCount += 1
        return isConnectedValue
    }

    func checkConnection() async -> Bool {
        checkConnectionCallCount += 1
        return checkConnectionValue
    }
}

@MainActor
final class CategoryServiceSpy: CategoryServiceProtocol {
    private(set) var loadCategoriesCallCount = 0
    private(set) var nameRequests: [String] = []
    private(set) var categoryRequests: [String] = []
    private(set) var iconRequests: [String] = []
    private(set) var colorRequests: [String] = []
    private(set) var allCategoriesCallCount = 0

    var categories: [AppCategory] = []
    var namesById: [String: String] = [:]

    func loadCategories() async {
        loadCategoriesCallCount += 1
    }

    func name(for categoryId: String) -> String {
        nameRequests.append(categoryId)
        return namesById[categoryId] ?? categories.first(where: { $0.id == categoryId })?.name ?? categoryId
    }

    func category(for categoryId: String) -> AppCategory? {
        categoryRequests.append(categoryId)
        return categories.first(where: { $0.id == categoryId })
    }

    func icon(for categoryId: String) -> String? {
        iconRequests.append(categoryId)
        return categories.first(where: { $0.id == categoryId })?.icon
    }

    func color(for categoryId: String) -> String? {
        colorRequests.append(categoryId)
        return categories.first(where: { $0.id == categoryId })?.color
    }

    func allCategories() -> [AppCategory] {
        allCategoriesCallCount += 1
        return categories
    }
}

final class VideoCacheServiceSpy: VideoCacheServiceProtocol {
    private(set) var isVideoCachedRequests: [SignVideo] = []
    private(set) var isURLCachedRequests: [URL] = []
    private(set) var cachedVideoRequests: [SignVideo] = []
    private(set) var cachedOriginalURLRequests: [URL] = []
    private(set) var downloadVideoRequests: [SignVideo] = []
    private(set) var downloadURLRequests: [URL] = []
    private(set) var preloadVideoRequests: [SignVideo] = []
    private(set) var preloadVideosRequests: [[SignVideo]] = []
    private(set) var clearCacheVideoRequests: [SignVideo] = []
    private(set) var clearCacheURLRequests: [URL] = []
    private(set) var clearCacheSignRequests: [(signId: String, videos: [SignVideo])] = []
    private(set) var clearAllCacheCallCount = 0
    private(set) var getCacheSizeCallCount = 0
    private(set) var ensureCacheLimitCallCount = 0

    var isVideoCachedValue = false
    var cachedVideoURLValue: URL?
    var downloadVideoResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/cached-video.mp4"))
    var downloadURLResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/cached-url.mp4"))
    var cacheSize = 0

    func isVideoCached(_ video: SignVideo) -> Bool {
        isVideoCachedRequests.append(video)
        return isVideoCachedValue
    }

    func isVideoCached(url: URL) -> Bool {
        isURLCachedRequests.append(url)
        return isVideoCachedValue
    }

    func getCachedVideoURL(_ video: SignVideo) -> URL? {
        cachedVideoRequests.append(video)
        return cachedVideoURLValue
    }

    func getCachedVideoURL(originalURL: URL) -> URL? {
        cachedOriginalURLRequests.append(originalURL)
        return cachedVideoURLValue
    }

    func downloadAndCache(video: SignVideo) async throws -> URL {
        downloadVideoRequests.append(video)
        return try downloadVideoResult.get()
    }

    func downloadAndCache(url: URL) async throws -> URL {
        downloadURLRequests.append(url)
        return try downloadURLResult.get()
    }

    func preloadVideo(_ video: SignVideo) async {
        preloadVideoRequests.append(video)
    }

    func preloadVideos(_ videos: [SignVideo]) async {
        preloadVideosRequests.append(videos)
    }

    func clearCache(for video: SignVideo) {
        clearCacheVideoRequests.append(video)
    }

    func clearCache(for url: URL) {
        clearCacheURLRequests.append(url)
    }

    func clearCache(for signId: String, videos: [SignVideo]) {
        clearCacheSignRequests.append((signId, videos))
    }

    func clearAllCache() {
        clearAllCacheCallCount += 1
    }

    func getCacheSize() -> Int {
        getCacheSizeCallCount += 1
        return cacheSize
    }

    func ensureCacheLimit() {
        ensureCacheLimitCallCount += 1
    }
}
