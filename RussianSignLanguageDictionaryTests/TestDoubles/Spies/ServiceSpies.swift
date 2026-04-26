import Foundation
import Combine
@testable import RussianSignLanguageDictionary

final class NetworkMonitorSpy: NetworkMonitorProtocol {
    private(set) var isConnectedCallCount = 0
    private(set) var checkConnectionCallCount = 0

    var isConnectedValue = true
    var checkConnectionValue = true
    private let connectivitySubject = CurrentValueSubject<ConnectivityStatus, Never>(.connected)
    private let connectionRestoredSubject = PassthroughSubject<Void, Never>()

    var connectivityPublisher: AnyPublisher<ConnectivityStatus, Never> {
        connectivitySubject.eraseToAnyPublisher()
    }

    var connectionRestoredPublisher: AnyPublisher<Void, Never> {
        connectionRestoredSubject.eraseToAnyPublisher()
    }

    var connectivityStatus: ConnectivityStatus {
        connectivitySubject.value
    }

    func isConnected() -> Bool {
        isConnectedCallCount += 1
        return isConnectedValue
    }

    func checkConnection() async -> Bool {
        checkConnectionCallCount += 1
        return checkConnectionValue
    }

    func setConnectivityStatus(_ status: ConnectivityStatus) {
        let previousStatus = connectivitySubject.value
        connectivitySubject.send(status)
        isConnectedValue = status == .connected
        checkConnectionValue = status == .connected

        if previousStatus != .connected, status == .connected {
            connectionRestoredSubject.send(())
        }
    }
}

final class VideoCacheServiceSpy: VideoCacheServiceProtocol {
    private(set) var isVideoCachedRequests: [SignVideo] = []
    private(set) var isURLCachedRequests: [URL] = []
    private(set) var cachedVideoRequests: [SignVideo] = []
    private(set) var cachedOriginalURLRequests: [URL] = []
    private(set) var downloadVideoRequests: [SignVideo] = []
    private(set) var downloadURLRequests: [URL] = []
    private(set) var promoteCachedVideoRequests: [(video: SignVideo, localFileURL: URL)] = []
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
    var promoteCachedVideoResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/promoted-video.mp4"))
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

    func promoteCachedVideo(_ video: SignVideo, from localFileURL: URL) throws -> URL {
        promoteCachedVideoRequests.append((video, localFileURL))
        return try promoteCachedVideoResult.get()
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

final class SBERTSearchServiceSpy: SBERTSearchServiceProtocol {
    private(set) var queries: [String] = []
    private(set) var limits: [Int] = []
    private(set) var minSimilarities: [Double] = []

    var searchResult: Result<[SBERTSearchResult], Error> = .success([])
    var searchImplementation: ((String, Int, Double) async throws -> [SBERTSearchResult])?

    func search(
        query: String,
        limit: Int,
        minSimilarity: Double
    ) async throws -> [SBERTSearchResult] {
        queries.append(query)
        limits.append(limit)
        minSimilarities.append(minSimilarity)

        if let searchImplementation {
            return try await searchImplementation(query, limit, minSimilarity)
        }

        return try searchResult.get()
    }
}

final class HybridSearchServiceSpy: HybridSearchServiceProtocol {
    private(set) var hybridQueries: [String] = []
    private(set) var hybridLimits: [Int] = []
    private(set) var highQualityFlags: [Bool] = []
    private(set) var textQueries: [String] = []
    private(set) var textLimits: [Int] = []

    var hybridSearchResult: Result<[Sign], Error> = .success([])
    var textSearchResult: [Sign] = []
    var hybridSearchImplementation: ((String, Int, Bool) async throws -> [Sign])?
    var textSearchImplementation: ((String, Int) -> [Sign])?

    func performHybridSearch(
        query: String,
        limit: Int,
        useHighQualityThreshold: Bool
    ) async throws -> [Sign] {
        hybridQueries.append(query)
        hybridLimits.append(limit)
        highQualityFlags.append(useHighQualityThreshold)

        if let hybridSearchImplementation {
            return try await hybridSearchImplementation(query, limit, useHighQualityThreshold)
        }

        return try hybridSearchResult.get()
    }

    func performTextSearch(query: String, limit: Int) -> [Sign] {
        textQueries.append(query)
        textLimits.append(limit)

        if let textSearchImplementation {
            return textSearchImplementation(query, limit)
        }

        return Array(textSearchResult.prefix(limit))
    }
}

final class HybridSearchServiceBuilderSpy: HybridSearchServiceBuilderProtocol {
    private(set) var makeCalls: [(signs: [Sign], networkMonitor: NetworkMonitorProtocol)] = []

    var service: HybridSearchServiceProtocol

    init(service: HybridSearchServiceProtocol) {
        self.service = service
    }

    func make(
        signs: [Sign],
        networkMonitor: NetworkMonitorProtocol
    ) -> HybridSearchServiceProtocol {
        makeCalls.append((signs, networkMonitor))
        return service
    }
}
