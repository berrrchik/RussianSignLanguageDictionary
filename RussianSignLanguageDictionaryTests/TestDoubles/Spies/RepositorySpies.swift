import Foundation
@testable import RussianSignLanguageDictionary

final class SignRepositorySpy: SignRepositoryProtocol {
    private(set) var loadAllSignsCallCount = 0
    private(set) var loadCategoriesCallCount = 0
    private(set) var getSignCallArguments: [String] = []
    private(set) var getSignsByCategoryArguments: [String] = []
    private(set) var searchQueries: [String] = []

    var loadAllSignsResult: Result<[Sign], Error> = .success([])
    var loadCategoriesResult: Result<[AppCategory], Error> = .success([])
    var getSignResult: Result<Sign?, Error> = .success(nil)
    var getSignsByCategoryResult: Result<[Sign], Error> = .success([])
    var searchSignsResult: Result<[Sign], Error> = .success([])
    var cachedSignsValue: [Sign]?

    func loadAllSigns() async throws -> [Sign] {
        loadAllSignsCallCount += 1
        return try loadAllSignsResult.get()
    }

    func loadCategories() async throws -> [AppCategory] {
        loadCategoriesCallCount += 1
        return try loadCategoriesResult.get()
    }

    func getSign(byId id: String) async throws -> Sign? {
        getSignCallArguments.append(id)
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
}

final class VideoRepositorySpy: VideoRepositoryProtocol {
    private(set) var cachedVideoRequests: [SignVideo] = []
    private(set) var signRequests: [Sign] = []
    private(set) var lessonRequests: [Lesson] = []
    private(set) var videoRequests: [(video: SignVideo, useFavoritesCache: Bool)] = []
    private(set) var preloadSignRequests: [Sign] = []
    private(set) var preloadVideoRequests: [(video: SignVideo, useFavoritesCache: Bool)] = []
    private(set) var clearCacheCallCount = 0

    var cachedVideoURLValue: URL?
    var signVideoURLResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/video.mp4"))
    var lessonVideoURLResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/lesson.mp4"))
    var directVideoURLResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/direct-video.mp4"))
    var preloadSignError: Error?
    var preloadVideoError: Error?

    func cachedVideoURL(for video: SignVideo) -> URL? {
        cachedVideoRequests.append(video)
        return cachedVideoURLValue
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

final class FavoritesRepositorySpy: FavoritesRepositoryProtocol {
    private(set) var addFavoriteCalls: [String] = []
    private(set) var removeFavoriteCalls: [String] = []
    private(set) var isFavoriteCalls: [String] = []
    private(set) var getFavoritesCallCount = 0
    private(set) var clearAllFavoritesCallCount = 0

    var favorites: [String] = []
    var favoriteLookup: [String: Bool] = [:]

    func getFavorites() -> [String] {
        getFavoritesCallCount += 1
        return favorites
    }

    func addFavorite(signId: String) {
        addFavoriteCalls.append(signId)
    }

    func removeFavorite(signId: String) {
        removeFavoriteCalls.append(signId)
    }

    func isFavorite(signId: String) -> Bool {
        isFavoriteCalls.append(signId)
        return favoriteLookup[signId] ?? false
    }

    func clearAllFavorites() {
        clearAllFavoritesCallCount += 1
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

    func fetchAllData(cachedDataProvider: @escaping () throws -> SyncData) async throws -> SyncData {
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
