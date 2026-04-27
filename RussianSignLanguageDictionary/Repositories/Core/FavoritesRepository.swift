import Combine
import Foundation
import os.log

/// Репозиторий для работы с избранными жестами через UserDefaults
///
/// Хранит три независимых слоя состояния:
/// - membership: сам факт, что жест находится в избранном;
/// - snapshot: локальная копия данных жеста для офлайн-списка;
/// - offline status: подготовка долгосрочного кеша видео.
@MainActor
final class FavoritesRepository: FavoritesRepositoryProtocol, ObservableObject {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.rsl.favorites", category: "FavoritesRepository")
    private let legacyFavoritesKey = "com.rsl.favorites"
    private let favoriteEntriesKey = "com.rsl.favoriteEntries"
    private let userDefaults: UserDefaults
    private let videoCacheService: VideoCacheServiceProtocol

    @Published private(set) var favoritesPublisher: [String] = []
    @Published private(set) var favoriteEntriesPublisher: [FavoriteEntry] = []

    // MARK: - Initialization

    init(
        userDefaults: UserDefaults = .standard,
        videoCacheService: VideoCacheServiceProtocol
    ) {
        self.userDefaults = userDefaults
        self.videoCacheService = videoCacheService

        let restoredEntries = Self.restoreEntries(
            from: userDefaults,
            favoriteEntriesKey: favoriteEntriesKey,
            legacyFavoritesKey: legacyFavoritesKey
        )
        applyPersistedEntries(restoredEntries, persist: true)
    }

    // MARK: - FavoritesRepositoryProtocol

    func getFavorites() -> [String] {
        favoriteEntriesPublisher.map(\.signId)
    }

    func getFavoriteEntries() -> [FavoriteEntry] {
        favoriteEntriesPublisher
    }

    func cachedFavoriteSnapshot(signId: String) -> FavoriteSignSnapshot? {
        getFavoriteEntry(signId: signId)?.snapshot
    }

    func failedFavoriteEntries() -> [FavoriteEntry] {
        favoriteEntriesPublisher.filter { $0.offlineStatus == .failed }
    }

    func reconcileOfflineState() async {
        let currentEntries = favoriteEntriesPublisher
        let reconciledEntries = currentEntries.map(reconciledEntry)

        guard reconciledEntries != currentEntries else { return }
        favoriteEntriesPublisher = reconciledEntries
        persistEntries()
    }

    func addFavorite(signId: String) {
        guard indexOfFavorite(signId: signId) == nil else { return }
        favoriteEntriesPublisher.append(FavoriteEntry(signId: signId))
        persistEntries()
        logger.info("⭐️ Жест \(signId) добавлен в избранное")
    }

    func addFavorite(sign: Sign, categoryName: String) {
        if let index = indexOfFavorite(signId: sign.id) {
            favoriteEntriesPublisher[index].snapshot = FavoriteSignSnapshot(
                sign: sign,
                categoryName: categoryName
            )
            favoriteEntriesPublisher[index].updatedAt = Date()
            persistEntries()
            return
        }

        let entry = FavoriteEntry(
            signId: sign.id,
            snapshot: FavoriteSignSnapshot(sign: sign, categoryName: categoryName)
        )
        favoriteEntriesPublisher.append(entry)
        persistEntries()
        logger.info("⭐️ Жест \(sign.id) добавлен в избранное со snapshot")
    }

    func updateFavoriteSnapshot(sign: Sign, categoryName: String) {
        guard let index = indexOfFavorite(signId: sign.id) else { return }
        favoriteEntriesPublisher[index].snapshot = FavoriteSignSnapshot(
            sign: sign,
            categoryName: categoryName
        )
        favoriteEntriesPublisher[index].updatedAt = Date()
        persistEntries()
    }

    func updateOfflineStatus(
        signId: String,
        status: FavoriteOfflineStatus,
        downloadedVideoIds: [Int],
        requiredVideoIds: [Int]
    ) {
        guard let index = indexOfFavorite(signId: signId) else { return }

        favoriteEntriesPublisher[index].offlineStatus = status
        favoriteEntriesPublisher[index].requiredVideoIds = requiredVideoIds
        favoriteEntriesPublisher[index].downloadedVideos = downloadedVideoIds.map {
            FavoriteOfflineVideo(videoId: $0)
        }
        favoriteEntriesPublisher[index].updatedAt = Date()
        persistEntries()
        logger.info("📦 Статус офлайн-подготовки для \(signId): \(status.rawValue)")
    }

    func removeFavorite(signId: String) {
        guard let index = indexOfFavorite(signId: signId) else { return }

        let entry = favoriteEntriesPublisher[index]
        favoriteEntriesPublisher.remove(at: index)
        persistEntries()

        clearVideoCache(for: entry)
        logger.info("💔 Жест \(signId) удалён из избранного")
    }

    func isFavorite(signId: String) -> Bool {
        indexOfFavorite(signId: signId) != nil
    }

    func clearAllFavorites() {
        favoriteEntriesPublisher = []
        persistEntries()
        videoCacheService.clearAllCache()
        logger.info("🗑️ Все избранные жесты очищены")
    }

    // MARK: - Private Methods

    private func indexOfFavorite(signId: String) -> Int? {
        favoriteEntriesPublisher.firstIndex { $0.signId == signId }
    }

    private func clearVideoCache(for entry: FavoriteEntry) {
        guard let videos = entry.snapshot?.sign.videos, !videos.isEmpty else { return }
        videoCacheService.clearCache(for: entry.signId, videos: videos)
    }

    private func reconciledEntry(_ entry: FavoriteEntry) -> FavoriteEntry {
        let now = Date()

        guard let snapshot = entry.snapshot else {
            guard entry.offlineStatus != .failed || !entry.downloadedVideos.isEmpty else {
                return entry
            }

            var reconciled = entry
            reconciled.offlineStatus = .failed
            reconciled.downloadedVideos = []
            reconciled.updatedAt = now
            return reconciled
        }

        let videos = snapshot.sign.videosArray
        let requiredVideoIds = videos.map(\.id)
        let downloadedVideos = videos
            .filter { videoCacheService.isVideoCached($0) }
            .map { FavoriteOfflineVideo(videoId: $0.id) }
        let offlineStatus: FavoriteOfflineStatus =
            requiredVideoIds.isEmpty || downloadedVideos.count == requiredVideoIds.count
            ? .readyOffline
            : .failed

        guard entry.requiredVideoIds != requiredVideoIds ||
              entry.downloadedVideos != downloadedVideos ||
              entry.offlineStatus != offlineStatus else {
            return entry
        }

        var reconciled = entry
        reconciled.requiredVideoIds = requiredVideoIds
        reconciled.downloadedVideos = downloadedVideos
        reconciled.offlineStatus = offlineStatus
        reconciled.updatedAt = now
        return reconciled
    }

    private func applyPersistedEntries(_ entries: [FavoriteEntry], persist: Bool) {
        favoriteEntriesPublisher = entries
        favoritesPublisher = entries.map(\.signId)

        if persist {
            persistEntries()
        }
    }

    private func persistEntries() {
        do {
            let data = try APIJSONEncoder.shared.encode(favoriteEntriesPublisher)
            userDefaults.set(data, forKey: favoriteEntriesKey)
        } catch {
            logger.error("❌ Не удалось сохранить favorite entries: \(error.localizedDescription)")
        }

        let favoriteIds = favoriteEntriesPublisher.map(\.signId)
        favoritesPublisher = favoriteIds
        userDefaults.set(favoriteIds, forKey: legacyFavoritesKey)
    }

    private static func restoreEntries(
        from userDefaults: UserDefaults,
        favoriteEntriesKey: String,
        legacyFavoritesKey: String
    ) -> [FavoriteEntry] {
        if let data = userDefaults.data(forKey: favoriteEntriesKey),
           let entries = try? APIJSONDecoder.shared.decode([FavoriteEntry].self, from: data) {
            return entries
        }

        let legacyIds = userDefaults.stringArray(forKey: legacyFavoritesKey) ?? []
        return legacyIds.map { FavoriteEntry(signId: $0) }
    }
}
