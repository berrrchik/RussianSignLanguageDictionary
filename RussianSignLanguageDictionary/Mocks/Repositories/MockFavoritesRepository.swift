import Foundation

#if DEBUG
/// Mock реализация FavoritesRepositoryProtocol для превью и тестов
final class MockFavoritesRepository: FavoritesRepositoryProtocol {
    // MARK: - Properties
    
    private var entries: [FavoriteEntry] = []
    
    // MARK: - Init
    
    init(initialFavorites: [String] = []) {
        self.entries = initialFavorites.map { FavoriteEntry(signId: $0) }
    }
    
    // MARK: - FavoritesRepositoryProtocol
    
    func getFavorites() -> [String] {
        entries.map(\.signId)
    }

    func getFavoriteEntries() -> [FavoriteEntry] {
        entries
    }
    
    func addFavorite(signId: String) {
        guard !entries.contains(where: { $0.signId == signId }) else { return }
        entries.append(FavoriteEntry(signId: signId))
    }

    func addFavorite(sign: Sign, categoryName: String) {
        if let index = entries.firstIndex(where: { $0.signId == sign.id }) {
            entries[index].snapshot = FavoriteSignSnapshot(sign: sign, categoryName: categoryName)
            return
        }

        entries.append(
            FavoriteEntry(
                signId: sign.id,
                snapshot: FavoriteSignSnapshot(sign: sign, categoryName: categoryName)
            )
        )
    }

    func updateFavoriteSnapshot(sign: Sign, categoryName: String) {
        guard let index = entries.firstIndex(where: { $0.signId == sign.id }) else { return }
        entries[index].snapshot = FavoriteSignSnapshot(sign: sign, categoryName: categoryName)
    }

    func updateOfflineStatus(
        signId: String,
        status: FavoriteOfflineStatus,
        downloadedVideoIds: [Int],
        requiredVideoIds: [Int]
    ) {
        guard let index = entries.firstIndex(where: { $0.signId == signId }) else { return }
        entries[index].offlineStatus = status
        entries[index].requiredVideoIds = requiredVideoIds
        entries[index].downloadedVideos = downloadedVideoIds.map { FavoriteOfflineVideo(videoId: $0) }
    }
    
    func removeFavorite(signId: String) {
        entries.removeAll { $0.signId == signId }
    }
    
    func isFavorite(signId: String) -> Bool {
        entries.contains { $0.signId == signId }
    }
    
    func clearAllFavorites() {
        entries.removeAll()
    }
}

// MARK: - Shared Instances

extension MockFavoritesRepository {
    /// Общий экземпляр для использования в Preview с предустановленными данными
    static let shared: MockFavoritesRepository = {
        let repo = MockFavoritesRepository()
        repo.addFavorite(signId: "sign_001")
        repo.addFavorite(signId: "sign_002")
        repo.addFavorite(signId: "sign_003")
        return repo
    }()
    
    /// Пустой экземпляр для Preview без избранного
    static let empty = MockFavoritesRepository()
}
#endif
