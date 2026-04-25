import Combine
import Foundation
import os.log

/// Репозиторий для работы с избранными жестами через UserDefaults
///
/// Хранит три независимых слоя состояния:
/// - membership: сам факт, что жест находится в избранном;
/// - snapshot: локальная копия данных жеста для офлайн-списка;
/// - offline status: подготовка долгосрочного кеша видео.
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

    func addFavorite(signId: String) {
        mutateEntriesOnMainThread {
            guard self.indexOfFavorite(signId: signId) == nil else {
                return
            }

            self.favoriteEntriesPublisher.append(FavoriteEntry(signId: signId))
            self.persistEntries()
            self.logger.info("⭐️ Жест \(signId) добавлен в избранное")
        }
    }

    func addFavorite(sign: Sign, categoryName: String) {
        mutateEntriesOnMainThread {
            if let index = self.indexOfFavorite(signId: sign.id) {
                self.favoriteEntriesPublisher[index].snapshot = FavoriteSignSnapshot(
                    sign: sign,
                    categoryName: categoryName
                )
                self.favoriteEntriesPublisher[index].updatedAt = Date()
                self.persistEntries()
                return
            }

            let entry = FavoriteEntry(
                signId: sign.id,
                snapshot: FavoriteSignSnapshot(sign: sign, categoryName: categoryName)
            )
            self.favoriteEntriesPublisher.append(entry)
            self.persistEntries()
            self.logger.info("⭐️ Жест \(sign.id) добавлен в избранное со snapshot")
        }
    }

    func updateFavoriteSnapshot(sign: Sign, categoryName: String) {
        mutateEntriesOnMainThread {
            guard let index = self.indexOfFavorite(signId: sign.id) else { return }
            self.favoriteEntriesPublisher[index].snapshot = FavoriteSignSnapshot(
                sign: sign,
                categoryName: categoryName
            )
            self.favoriteEntriesPublisher[index].updatedAt = Date()
            self.persistEntries()
        }
    }

    func updateOfflineStatus(
        signId: String,
        status: FavoriteOfflineStatus,
        downloadedVideoIds: [Int],
        requiredVideoIds: [Int]
    ) {
        mutateEntriesOnMainThread {
            guard let index = self.indexOfFavorite(signId: signId) else { return }

            self.favoriteEntriesPublisher[index].offlineStatus = status
            self.favoriteEntriesPublisher[index].requiredVideoIds = requiredVideoIds
            self.favoriteEntriesPublisher[index].downloadedVideos = downloadedVideoIds.map {
                FavoriteOfflineVideo(videoId: $0)
            }
            self.favoriteEntriesPublisher[index].updatedAt = Date()
            self.persistEntries()
            self.logger.info("📦 Статус офлайн-подготовки для \(signId): \(status.rawValue)")
        }
    }

    func removeFavorite(signId: String) {
        mutateEntriesOnMainThread {
            guard let index = self.indexOfFavorite(signId: signId) else { return }

            let entry = self.favoriteEntriesPublisher[index]
            self.favoriteEntriesPublisher.remove(at: index)
            self.persistEntries()

            self.clearVideoCache(for: entry)
            self.logger.info("💔 Жест \(signId) удалён из избранного")
        }
    }

    func isFavorite(signId: String) -> Bool {
        indexOfFavorite(signId: signId) != nil
    }

    func clearAllFavorites() {
        mutateEntriesOnMainThread {
            self.favoriteEntriesPublisher = []
            self.persistEntries()
            self.videoCacheService.clearAllCache()
            self.logger.info("🗑️ Все избранные жесты очищены")
        }
    }

    // MARK: - Private Methods

    private func mutateEntriesOnMainThread(_ mutation: @escaping () -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync {
                mutation()
            }
            return
        }

        mutation()
    }

    private func indexOfFavorite(signId: String) -> Int? {
        favoriteEntriesPublisher.firstIndex { $0.signId == signId }
    }

    private func clearVideoCache(for entry: FavoriteEntry) {
        guard let videos = entry.snapshot?.sign.videos, !videos.isEmpty else { return }
        videoCacheService.clearCache(for: entry.signId, videos: videos)
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
