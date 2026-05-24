import Foundation
import os.log

/// Репозиторий для работы с видео с сервера.
///
/// Поддерживает двухуровневое кеширование:
/// - **Краткосрочный кеш**: LRU-кеш в `Caches/video_short_term_cache/` (до 150 MB),
///   управляется `ShortTermVideoCacheManager`
/// - **Долгосрочный кеш**: файлы на диске для избранных жестов (до 500 MB),
///   управляется `VideoCacheService`
///
/// **Performance Monitoring**: операции загрузки видео отслеживаются через Firebase Performance:
/// - `video_load_favorites_cache` — загрузка из долгосрочного кеша избранных
/// - `video_download_network` — загрузка видео с сервера в краткосрочный кеш (внутри `ShortTermVideoCacheManager`)
final class VideoRepository: VideoRepositoryProtocol {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.rsl.videoRepository", category: "VideoRepository")

    /// Сервис долгосрочного кеша (файлы на диске для избранных жестов)
    private let videoCacheService: VideoCacheServiceProtocol

    /// Монитор сети для проверки доступности интернета
    private let networkMonitor: NetworkMonitorProtocol

    /// Менеджер краткосрочного LRU-кеша
    private let shortTermCache: ShortTermVideoCacheManagerProtocol

    // MARK: - Initialization

    init(
        videoCacheService: VideoCacheServiceProtocol,
        networkMonitor: NetworkMonitorProtocol,
        shortTermCache: ShortTermVideoCacheManagerProtocol? = nil
    ) {
        self.videoCacheService = videoCacheService
        self.networkMonitor = networkMonitor
        self.shortTermCache = shortTermCache
            ?? ShortTermVideoCacheManager(networkMonitor: networkMonitor)
        logger.info("✅ VideoRepository инициализирован")
    }

    // MARK: - VideoRepositoryProtocol

    func cachedVideoURL(for video: SignVideo) -> URL? {
        shortTermCache.cachedVideoURL(for: video)
            ?? videoCacheService.getCachedVideoURL(video)
    }

    func getVideoURL(for sign: Sign) async throws -> URL {
        guard let firstVideo = sign.videos?.first else {
            throw VideoRepositoryError.invalidURL
        }
        return try await getVideoURL(for: firstVideo, useFavoritesCache: false)
    }

    func getVideoURL(for video: SignVideo, useFavoritesCache: Bool = false) async throws -> URL {
        guard let url = APIConfig.videoURL(forPath: video.url) else {
            throw VideoRepositoryError.invalidURL
        }

        if useFavoritesCache {
            return try await getVideoURLFromFavoritesCache(url: url, video: video)
        } else {
            return try await shortTermCache.downloadVideo(url: url, video: video)
        }
    }

    func getVideoURL(for lesson: Lesson) async throws -> URL {
        guard APIConfig.videoURL(forPath: lesson.videoUrl) != nil else {
            logger.error("❌ Lesson video: невалидный путь для урока \(lesson.id) (\(lesson.videoUrl))")
            throw VideoRepositoryError.invalidURL
        }
        return try await getVideoURL(for: signVideo(for: lesson), useFavoritesCache: false)
    }

    func preloadVideo(for sign: Sign) async throws {
        _ = try await getVideoURL(for: sign)
    }

    func preloadVideo(video: SignVideo, useFavoritesCache: Bool = true) async throws {
        if useFavoritesCache {
            logger.info("📥 Предзагрузка видео \(video.id) в долгосрочный кеш")
            await videoCacheService.preloadVideo(video)
        } else {
            _ = try await getVideoURL(for: video, useFavoritesCache: false)
        }
    }

    func clearCache() {
        shortTermCache.clear()
        logger.info("🗑️ Краткосрочный кеш очищен")
    }

    // MARK: - Private

    private func signVideo(for lesson: Lesson) -> SignVideo {
        SignVideo(
            id: stableLessonVideoId(lesson.id),
            url: lesson.videoUrl,
            contextDescription: lesson.title,
            order: lesson.order,
            createdAt: lesson.createdAt,
            updatedAt: lesson.updatedAt
        )
    }

    private func stableLessonVideoId(_ lessonId: String) -> Int {
        lessonId.utf8.reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) }
    }

    /// Получает URL из долгосрочного кеша (для избранных жестов).
    ///
    /// Стратегия (в порядке приоритета):
    /// 1. Долгосрочный кеш (`VideoCacheService`)
    /// 2. Краткосрочный кеш → перенос в долгосрочный
    /// 3. Загрузка с сервера → сохранение в долгосрочный кеш
    private func getVideoURLFromFavoritesCache(url: URL, video: SignVideo) async throws -> URL {
        let videoId = String(video.id)
        let trace = PerformanceService.startTrace("video_load_favorites_cache")
        PerformanceService.addAttribute(trace, name: "video_id", value: videoId)
        defer { PerformanceService.stopTrace(trace) }

        // 1. Долгосрочный кеш
        if let cachedFileURL = videoCacheService.getCachedVideoURL(video) {
            logger.info("✅ Видео \(videoId) загружено из долгосрочного кеша")
            PerformanceService.addAttribute(trace, name: "source", value: "cache")
            return cachedFileURL
        }

        // 2. Краткосрочный кеш → перенос в долгосрочный
        if let shortTermURL = shortTermCache.cachedVideoURL(for: video) {
            do {
                let promotedURL = try videoCacheService.promoteCachedVideo(video, from: shortTermURL)
                logger.info("✅ Видео \(videoId) перенесено из краткосрочного в долгосрочный кеш")
                PerformanceService.addAttribute(trace, name: "source", value: "short_term_promotion")
                return promotedURL
            } catch {
                logger.warning("⚠️ Не удалось перенести видео \(videoId): \(error.localizedDescription)")
            }
        }

        // 3. Сеть
        let isConnected = await networkMonitor.checkConnection()
        guard isConnected else {
            logger.warning("⚠️ Видео \(videoId) не найдено в кеше и нет интернета")
            PerformanceService.addAttribute(trace, name: "error", value: "no_internet")
            throw VideoRepositoryError.noInternetConnection
        }

        logger.info("📥 Загрузка видео \(videoId) с сервера в долгосрочный кеш...")
        PerformanceService.addAttribute(trace, name: "source", value: "network")

        do {
            let cachedFileURL = try await videoCacheService.downloadAndCache(video: video)
            logger.info("✅ Видео \(videoId) сохранено в долгосрочный кеш")
            if let fileSize = try? cachedFileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                PerformanceService.incrementMetric(trace, name: "video_size_bytes", by: Int64(fileSize))
            }
            return cachedFileURL
        } catch let error as VideoCacheError {
            PerformanceService.addAttribute(trace, name: "error", value: error.localizedDescription)
            throw VideoRepositoryError.from(error)
        } catch {
            logger.error("❌ Ошибка загрузки видео \(videoId): \(error.localizedDescription)")
            PerformanceService.addAttribute(trace, name: "error", value: error.localizedDescription)
            throw mapVideoError(error)
        }
    }

    private func mapVideoError(_ error: Error) -> VideoRepositoryError {
        if let repositoryError = error as? VideoRepositoryError { return repositoryError }
        if let cacheError = error as? VideoCacheError { return VideoRepositoryError.from(cacheError) }
        guard let urlError = error as? URLError else { return .videoUnavailable }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noInternetConnection
        case .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .badServerResponse:
            return .videoUnavailable
        default:
            return .videoUnavailable
        }
    }
}
