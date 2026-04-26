import Foundation
import Combine
@testable import RussianSignLanguageDictionary

final class SignRepositoryFake: SignRepositoryProtocol {
    private(set) var signsById: [String: Sign]
    private(set) var categoriesById: [String: AppCategory]
    private let cachedSignsStorage: [Sign]?
    private let dataUpdatedSubject = PassthroughSubject<SyncData, Never>()
    private let dataStatusSubject = CurrentValueSubject<RepositoryDataStatus, Never>(.updated)

    init(
        signs: [Sign] = [TestFixtures.sign],
        categories: [AppCategory] = [TestFixtures.category],
        cachedSigns: [Sign]? = nil
    ) {
        self.signsById = Dictionary(uniqueKeysWithValues: signs.map { ($0.id, $0) })
        self.categoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        self.cachedSignsStorage = cachedSigns
    }

    var dataUpdatedPublisher: AnyPublisher<SyncData, Never> {
        dataUpdatedSubject.eraseToAnyPublisher()
    }

    var dataStatusPublisher: AnyPublisher<RepositoryDataStatus, Never> {
        dataStatusSubject.eraseToAnyPublisher()
    }

    var currentDataStatus: RepositoryDataStatus {
        dataStatusSubject.value
    }

    func loadAllSigns() async throws -> [Sign] {
        Array(signsById.values).sorted { $0.word < $1.word }
    }

    func loadCategories() async throws -> [AppCategory] {
        Array(categoriesById.values).sorted { $0.order < $1.order }
    }

    func getSign(byId id: String) async throws -> Sign? {
        signsById[id]
    }

    func getSigns(byCategory categoryId: String) async throws -> [Sign] {
        signsById.values.filter { $0.categoryId == categoryId }.sorted { $0.word < $1.word }
    }

    func searchSigns(query: String) async throws -> [Sign] {
        guard !query.isEmpty else { return [] }
        return signsById.values.filter { $0.word.localizedCaseInsensitiveContains(query) }.sorted { $0.word < $1.word }
    }

    func cachedSigns() -> [Sign]? {
        cachedSignsStorage
    }

    func cachedData() -> SyncData? {
        guard let cachedSignsStorage else { return nil }
        return SyncData(
            categories: Array(categoriesById.values).sorted { $0.order < $1.order },
            signs: cachedSignsStorage,
            lessons: [],
            lastUpdated: Date()
        )
    }
}

final class FavoritesRepositoryFake: FavoritesRepositoryProtocol {
    private var entries: [FavoriteEntry]

    init(initialFavorites: [String] = []) {
        entries = initialFavorites.map { FavoriteEntry(signId: $0) }
    }

    func getFavorites() -> [String] {
        entries.map(\.signId)
    }

    func getFavoriteEntries() -> [FavoriteEntry] {
        entries
    }

    func cachedFavoriteSnapshot(signId: String) -> FavoriteSignSnapshot? {
        entries.first(where: { $0.signId == signId })?.snapshot
    }

    func failedFavoriteEntries() -> [FavoriteEntry] {
        entries.filter { $0.offlineStatus == .failed }
    }

    func reconcileOfflineState() -> [FavoriteEntry] {
        entries
    }

    func addFavorite(signId: String) {
        guard !entries.contains(where: { $0.signId == signId }) else { return }
        entries.append(FavoriteEntry(signId: signId))
    }

    func addFavorite(sign: Sign, categoryName: String) {
        if let index = entries.firstIndex(where: { $0.signId == sign.id }) {
            entries[index].snapshot = FavoriteSignSnapshot(sign: sign, categoryName: categoryName)
        } else {
            entries.append(
                FavoriteEntry(
                    signId: sign.id,
                    snapshot: FavoriteSignSnapshot(sign: sign, categoryName: categoryName)
                )
            )
        }
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
