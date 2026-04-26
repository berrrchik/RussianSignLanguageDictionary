import Foundation
import Combine
@testable import RussianSignLanguageDictionary

final class NetworkMonitorStub: NetworkMonitorProtocol {
    let connected: Bool
    private let connectivitySubject: CurrentValueSubject<ConnectivityStatus, Never>

    init(connected: Bool) {
        self.connected = connected
        self.connectivitySubject = CurrentValueSubject(connected ? .connected : .disconnected)
    }

    var connectivityPublisher: AnyPublisher<ConnectivityStatus, Never> {
        connectivitySubject.eraseToAnyPublisher()
    }

    var connectionRestoredPublisher: AnyPublisher<Void, Never> {
        Empty<Void, Never>().eraseToAnyPublisher()
    }

    var connectivityStatus: ConnectivityStatus {
        connectivitySubject.value
    }

    func isConnected() -> Bool {
        connected
    }

    func checkConnection() async -> Bool {
        connected
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

    func promoteCachedVideo(_ video: SignVideo, from localFileURL: URL) throws -> URL {
        cachedURL ?? URL(fileURLWithPath: "/tmp/promoted-video-stub.mp4")
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
