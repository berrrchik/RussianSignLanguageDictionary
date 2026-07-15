import Foundation

/// Мок-реализация VideoCacheServiceProtocol для тестирования
/// `VideoCacheServiceProtocol` требует синхронных non-async методов, читающих/пишущих
/// мутируемое состояние (`cachedVideos`, счётчики), поэтому его нельзя целиком изолировать
/// к MainActor без переписывания протокола. `@unchecked Sendable` безопасен только потому,
/// что этот мок используется исключительно из Previews и `@MainActor`-тестов (см. CLAUDE.md
/// конвенцию: ViewModel-тесты всегда `@MainActor`) — фактически однопоточно, без гонок.
final class MockVideoCacheService: VideoCacheServiceProtocol, @unchecked Sendable {
    // MARK: - Test Control Properties
    
    /// Словарь закешированных видео (URL строка -> локальный URL)
    var cachedVideos: [String: URL] = [:]
    
    /// Симуляция ошибки загрузки
    var shouldFailDownload: Bool = false
    
    /// Количество вызовов preloadVideo
    var preloadVideoCallCount: Int = 0
    
    /// Количество вызовов clearCache
    var clearCacheCallCount: Int = 0
    
    /// Количество вызовов clearAllCache
    var clearAllCacheCallCount: Int = 0
    
    /// Последние переданные видео для preload
    var lastPreloadedVideos: [SignVideo] = []
    
    /// Размер кеша для тестов
    var mockCacheSize: Int = 0
    
    // MARK: - VideoCacheServiceProtocol
    
    func isVideoCached(_ video: SignVideo) -> Bool {
        return cachedVideos[video.url] != nil
    }
    
    func isVideoCached(url: URL) -> Bool {
        return cachedVideos[url.absoluteString] != nil
    }
    
    func getCachedVideoURL(_ video: SignVideo) -> URL? {
        return cachedVideos[video.url]
    }
    
    func getCachedVideoURL(originalURL: URL) -> URL? {
        return cachedVideos[originalURL.absoluteString]
    }
    
    func downloadAndCache(video: SignVideo) async throws -> URL {
        if shouldFailDownload {
            throw VideoCacheError.videoUnavailable
        }
        
        let localURL = URL(fileURLWithPath: "/tmp/cached_\(video.id).mp4")
        cachedVideos[video.url] = localURL
        return localURL
    }
    
    func downloadAndCache(url: URL) async throws -> URL {
        if shouldFailDownload {
            throw VideoCacheError.videoUnavailable
        }
        
        let localURL = URL(fileURLWithPath: "/tmp/cached_\(url.lastPathComponent)")
        cachedVideos[url.absoluteString] = localURL
        return localURL
    }

    func promoteCachedVideo(_ video: SignVideo, from localFileURL: URL) throws -> URL {
        let localURL = URL(fileURLWithPath: "/tmp/favorites_\(video.id).mp4")
        cachedVideos[video.url] = localURL
        return localURL
    }
    
    func preloadVideo(_ video: SignVideo) async {
        preloadVideoCallCount += 1
        lastPreloadedVideos.append(video)
        
        if !shouldFailDownload {
            let localURL = URL(fileURLWithPath: "/tmp/cached_\(video.id).mp4")
            cachedVideos[video.url] = localURL
        }
    }
    
    func preloadVideos(_ videos: [SignVideo]) async {
        for video in videos {
            await preloadVideo(video)
        }
    }
    
    func clearCache(for video: SignVideo) {
        clearCacheCallCount += 1
        cachedVideos.removeValue(forKey: video.url)
    }
    
    func clearCache(for url: URL) {
        clearCacheCallCount += 1
        cachedVideos.removeValue(forKey: url.absoluteString)
    }
    
    func clearCache(for signId: String, videos: [SignVideo]) {
        clearCacheCallCount += 1
        for video in videos {
            cachedVideos.removeValue(forKey: video.url)
        }
    }
    
    func clearAllCache() {
        clearAllCacheCallCount += 1
        cachedVideos.removeAll()
    }
    
    func getCacheSize() -> Int {
        return mockCacheSize
    }
    
    func ensureCacheLimit() {
        // No-op в тестах
    }
    
    // MARK: - Test Helpers
    
    /// Сбрасывает все счётчики и состояние
    func reset() {
        cachedVideos.removeAll()
        shouldFailDownload = false
        preloadVideoCallCount = 0
        clearCacheCallCount = 0
        clearAllCacheCallCount = 0
        lastPreloadedVideos.removeAll()
        mockCacheSize = 0
    }
    
    /// Добавляет видео в кеш вручную (для настройки тестов)
    func addToCache(video: SignVideo, localURL: URL? = nil) {
        let url = localURL ?? URL(fileURLWithPath: "/tmp/cached_\(video.id).mp4")
        cachedVideos[video.url] = url
    }
}
