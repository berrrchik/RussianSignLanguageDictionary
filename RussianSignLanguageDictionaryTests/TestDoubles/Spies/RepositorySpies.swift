import Foundation
import Combine
@testable import RussianSignLanguageDictionary

final class SignRepositorySpy: SignRepositoryProtocol {
    private(set) var loadAllSignsCallCount = 0
    private(set) var loadCategoriesCallCount = 0
    private(set) var getSignCallArguments: [String] = []
    private(set) var getSignsByCategoryArguments: [String] = []
    private(set) var searchQueries: [String] = []

    let dataUpdatedSubject = PassthroughSubject<SyncData, Never>()
    let dataStatusSubject = CurrentValueSubject<RepositoryDataStatus, Never>(.idle)

    var loadAllSignsResult: Result<[Sign], Error> = .success([])
    var loadCategoriesResult: Result<[AppCategory], Error> = .success([])
    var getSignResult: Result<Sign?, Error> = .success(nil)
    var getSignsByCategoryResult: Result<[Sign], Error> = .success([])
    var searchSignsResult: Result<[Sign], Error> = .success([])
    var cachedSignsValue: [Sign]?
    var cachedDataValue: SyncData?
    var loadAllSignsImplementation: (() async throws -> [Sign])?
    var loadCategoriesImplementation: (() async throws -> [AppCategory])?
    var getSignImplementation: ((String) async throws -> Sign?)?

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
        loadAllSignsCallCount += 1
        if let loadAllSignsImplementation {
            return try await loadAllSignsImplementation()
        }
        return try loadAllSignsResult.get()
    }

    func loadCategories() async throws -> [AppCategory] {
        loadCategoriesCallCount += 1
        if let loadCategoriesImplementation {
            return try await loadCategoriesImplementation()
        }
        return try loadCategoriesResult.get()
    }

    func getSign(byId id: String) async throws -> Sign? {
        getSignCallArguments.append(id)
        if let getSignImplementation {
            return try await getSignImplementation(id)
        }
        return try getSignResult.get()
    }

    func getSigns(byCategory categoryId: String) async throws -> [Sign] {
        getSignsByCategoryArguments.append(categoryId)
        return try getSignsByCategoryResult.get()
    }

    func searchSigns(query: String) async throws -> [Sign] {
        searchQueries.append(query)
        return try searchSignsResult.get()
    }

    func cachedSigns() -> [Sign]? {
        cachedSignsValue
    }

    func cachedData() -> SyncData? {
        cachedDataValue
    }

    func setCurrentDataStatus(_ status: RepositoryDataStatus) {
        dataStatusSubject.send(status)
    }
}

@MainActor
final class VideoRepositorySpy: VideoRepositoryProtocol {
    /// Lock-protected state читаемое/мутируемое из `nonisolated func cachedVideoURL(for:)`,
    /// вызов которого не гарантированно происходит на MainActor.
    private nonisolated(unsafe) let cachedVideoLock = NSLock()
    private nonisolated(unsafe) var _cachedVideoRequests: [SignVideo] = []
    private nonisolated(unsafe) var _cachedVideoURLValue: URL?
    var cachedVideoRequests: [SignVideo] {
        cachedVideoLock.withLock { _cachedVideoRequests }
    }
    var cachedVideoURLValue: URL? {
        get { cachedVideoLock.withLock { _cachedVideoURLValue } }
        set { cachedVideoLock.withLock { _cachedVideoURLValue = newValue } }
    }

    private(set) var signRequests: [Sign] = []
    private(set) var lessonRequests: [Lesson] = []
    private(set) var videoRequests: [(video: SignVideo, useFavoritesCache: Bool)] = []
    private(set) var preloadSignRequests: [Sign] = []
    private(set) var preloadVideoRequests: [(video: SignVideo, useFavoritesCache: Bool)] = []
    private(set) var clearCacheCallCount = 0

    var signVideoURLResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/video.mp4"))
    var lessonVideoURLResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/lesson.mp4"))
    var directVideoURLResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/direct-video.mp4"))
    var preloadSignError: Error?
    var preloadVideoError: Error?
    var directVideoURLImplementation: ((SignVideo, Bool) async throws -> URL)?

    nonisolated func cachedVideoURL(for video: SignVideo) -> URL? {
        cachedVideoLock.withLock {
            _cachedVideoRequests.append(video)
            return _cachedVideoURLValue
        }
    }

    func getVideoURL(for sign: Sign) async throws -> URL {
        signRequests.append(sign)
        return try signVideoURLResult.get()
    }

    func getVideoURL(for lesson: Lesson) async throws -> URL {
        lessonRequests.append(lesson)
        return try lessonVideoURLResult.get()
    }

    func getVideoURL(for video: SignVideo, useFavoritesCache: Bool) async throws -> URL {
        videoRequests.append((video, useFavoritesCache))
        if let directVideoURLImplementation {
            return try await directVideoURLImplementation(video, useFavoritesCache)
        }
        return try directVideoURLResult.get()
    }

    func preloadVideo(for sign: Sign) async throws {
        preloadSignRequests.append(sign)
        if let preloadSignError {
            throw preloadSignError
        }
    }

    func preloadVideo(video: SignVideo, useFavoritesCache: Bool) async throws {
        preloadVideoRequests.append((video, useFavoritesCache))
        if let preloadVideoError {
            throw preloadVideoError
        }
    }

    func clearCache() {
        clearCacheCallCount += 1
    }
}

@MainActor
final class FavoritesRepositorySpy: FavoritesRepositoryProtocol {
    private(set) var addFavoriteCalls: [String] = []
    private(set) var addFavoriteWithSnapshotCalls: [(sign: Sign, categoryName: String)] = []
    private(set) var removeFavoriteCalls: [String] = []
    private(set) var isFavoriteCalls: [String] = []
    private(set) var getFavoritesCallCount = 0
    private(set) var getFavoriteEntriesCallCount = 0
    private(set) var reconcileOfflineStateCallCount = 0
    private(set) var clearAllFavoritesCallCount = 0
    private(set) var updateFavoriteSnapshotCalls: [(sign: Sign, categoryName: String)] = []
    private(set) var updateOfflineStatusCalls: [(signId: String, status: FavoriteOfflineStatus, downloadedVideoIds: [Int], requiredVideoIds: [Int])] = []

    var favorites: [String] = []
    var entries: [FavoriteEntry] = []
    var favoriteLookup: [String: Bool] = [:]
    var mutatesStoredFavorites = true

    func getFavorites() -> [String] {
        getFavoritesCallCount += 1
        return entries.map(\.signId).isEmpty ? favorites : entries.map(\.signId)
    }

    func getFavoriteEntries() -> [FavoriteEntry] {
        getFavoriteEntriesCallCount += 1
        return entries
    }

    func cachedFavoriteSnapshot(signId: String) -> FavoriteSignSnapshot? {
        entries.first(where: { $0.signId == signId })?.snapshot
    }

    func failedFavoriteEntries() -> [FavoriteEntry] {
        entries.filter { $0.offlineStatus == .failed }
    }

    func reconcileOfflineState() async {
        reconcileOfflineStateCallCount += 1
    }

    func addFavorite(signId: String) {
        addFavoriteCalls.append(signId)
        if mutatesStoredFavorites {
            if !favorites.contains(signId) {
                favorites.append(signId)
            }
            if !entries.contains(where: { $0.signId == signId }) {
                entries.append(FavoriteEntry(signId: signId))
            }
            favoriteLookup[signId] = true
        }
    }

    func addFavorite(sign: Sign, categoryName: String) {
        addFavoriteWithSnapshotCalls.append((sign, categoryName))
        if mutatesStoredFavorites {
            if !favorites.contains(sign.id) {
                favorites.append(sign.id)
            }
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
            favoriteLookup[sign.id] = true
        }
    }

    func updateFavoriteSnapshot(sign: Sign, categoryName: String) {
        updateFavoriteSnapshotCalls.append((sign, categoryName))
        guard mutatesStoredFavorites,
              let index = entries.firstIndex(where: { $0.signId == sign.id }) else {
            return
        }

        entries[index].snapshot = FavoriteSignSnapshot(sign: sign, categoryName: categoryName)
    }

    func updateOfflineStatus(
        signId: String,
        status: FavoriteOfflineStatus,
        downloadedVideoIds: [Int],
        requiredVideoIds: [Int]
    ) {
        updateOfflineStatusCalls.append((signId, status, downloadedVideoIds, requiredVideoIds))
        guard mutatesStoredFavorites,
              let index = entries.firstIndex(where: { $0.signId == signId }) else {
            return
        }

        entries[index].offlineStatus = status
        entries[index].requiredVideoIds = requiredVideoIds
        entries[index].downloadedVideos = downloadedVideoIds.map { FavoriteOfflineVideo(videoId: $0) }
    }

    func removeFavorite(signId: String) {
        removeFavoriteCalls.append(signId)
        if mutatesStoredFavorites {
            favorites.removeAll { $0 == signId }
            entries.removeAll { $0.signId == signId }
            favoriteLookup[signId] = false
        }
    }

    func isFavorite(signId: String) -> Bool {
        isFavoriteCalls.append(signId)
        return favoriteLookup[signId] ?? entries.contains { $0.signId == signId }
    }

    func clearAllFavorites() {
        clearAllFavoritesCallCount += 1
        if mutatesStoredFavorites {
            favorites.removeAll()
            entries.removeAll()
            favoriteLookup.removeAll()
        }
    }
}

final class SyncRepositorySpy: SyncRepositoryProtocol {
    private(set) var checkForUpdatesArguments: [Date?] = []
    private(set) var fetchAllDataCallCount = 0
    private(set) var cachedDataProviderCallCount = 0

    var checkForUpdatesResult: Result<SyncMetadata, Error> = .success(TestFixtures.syncMetadata)
    var fetchAllDataResult: Result<SyncData, Error> = .success(TestFixtures.syncData)
    var shouldInvokeCachedDataProvider = false
    var checkForUpdatesImplementation: ((Date?) async throws -> SyncMetadata)?
    var fetchAllDataImplementation: (((() throws -> SyncData)) async throws -> SyncData)?

    func checkForUpdates(lastUpdated: Date?) async throws -> SyncMetadata {
        checkForUpdatesArguments.append(lastUpdated)
        if let checkForUpdatesImplementation {
            return try await checkForUpdatesImplementation(lastUpdated)
        }
        return try checkForUpdatesResult.get()
    }

    func fetchAllData(cachedDataProvider: @escaping @Sendable () throws -> SyncData) async throws -> SyncData {
        fetchAllDataCallCount += 1

        if let fetchAllDataImplementation {
            return try await fetchAllDataImplementation(cachedDataProvider)
        }

        if shouldInvokeCachedDataProvider {
            cachedDataProviderCallCount += 1
            return try cachedDataProvider()
        }

        return try fetchAllDataResult.get()
    }
}

final class LessonRepositorySpy: LessonRepositoryProtocol {
    private(set) var loadAllLessonsCallCount = 0
    private(set) var getLessonCallArguments: [String] = []
    private(set) var getLessonsCallCount = 0

    var loadAllLessonsResult: Result<[Lesson], Error> = .success([])
    var getLessonResult: Result<Lesson?, Error> = .success(nil)
    var getLessonsResult: Result<[Lesson], Error> = .success([])
    var loadAllLessonsImplementation: (() async throws -> [Lesson])?
    var getLessonImplementation: ((String) async throws -> Lesson?)?
    var getLessonsImplementation: (() async throws -> [Lesson])?

    func loadAllLessons() async throws -> [Lesson] {
        loadAllLessonsCallCount += 1
        if let loadAllLessonsImplementation {
            return try await loadAllLessonsImplementation()
        }
        return try loadAllLessonsResult.get()
    }

    func getLesson(byId id: String) async throws -> Lesson? {
        getLessonCallArguments.append(id)
        if let getLessonImplementation {
            return try await getLessonImplementation(id)
        }
        return try getLessonResult.get()
    }

    func getLessons() async throws -> [Lesson] {
        getLessonsCallCount += 1
        if let getLessonsImplementation {
            return try await getLessonsImplementation()
        }
        return try getLessonsResult.get()
    }
}
