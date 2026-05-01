import Foundation
import Combine
@testable import RussianSignLanguageDictionary

final class SignRepositoryStub: SignRepositoryProtocol {
    var signs: [Sign]
    var categories: [AppCategory]
    var cachedSignsValue: [Sign]?
    private let dataUpdatedSubject = PassthroughSubject<SyncData, Never>()
    private let dataStatusSubject = CurrentValueSubject<RepositoryDataStatus, Never>(.updated)

    init(
        signs: [Sign] = [TestFixtures.sign],
        categories: [AppCategory] = [TestFixtures.category],
        cachedSigns: [Sign]? = nil
    ) {
        self.signs = signs
        self.categories = categories
        self.cachedSignsValue = cachedSigns
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
        signs
    }

    func loadCategories() async throws -> [AppCategory] {
        categories
    }

    func getSign(byId id: String) async throws -> Sign? {
        signs.first(where: { $0.id == id })
    }

    func getSigns(byCategory categoryId: String) async throws -> [Sign] {
        signs.filter { $0.categoryId == categoryId }
    }

    func searchSigns(query: String) async throws -> [Sign] {
        guard !query.isEmpty else { return signs }
        return signs.filter { $0.word.localizedCaseInsensitiveContains(query) }
    }

    func cachedSigns() -> [Sign]? {
        cachedSignsValue
    }

    func cachedData() -> SyncData? {
        guard let cachedSignsValue else { return nil }
        return SyncData(
            categories: categories,
            signs: cachedSignsValue,
            lessons: [],
            lastUpdated: Date()
        )
    }
}

final class VideoRepositoryStub: VideoRepositoryProtocol {
    let cachedURL: URL?
    let resultURL: URL

    init(
        cachedURL: URL? = nil,
        resultURL: URL = URL(fileURLWithPath: "/tmp/video-stub.mp4")
    ) {
        self.cachedURL = cachedURL
        self.resultURL = resultURL
    }

    func cachedVideoURL(for video: SignVideo) -> URL? {
        cachedURL
    }

    func getVideoURL(for sign: Sign) async throws -> URL {
        resultURL
    }

    func getVideoURL(for lesson: Lesson) async throws -> URL {
        resultURL
    }

    func getVideoURL(for video: SignVideo, useFavoritesCache: Bool) async throws -> URL {
        resultURL
    }

    func preloadVideo(for sign: Sign) async throws {}

    func preloadVideo(video: SignVideo, useFavoritesCache: Bool) async throws {}

    func clearCache() {}
}

final class SyncRepositoryStub: SyncRepositoryProtocol {
    let metadata: SyncMetadata
    let data: SyncData

    init(
        metadata: SyncMetadata = TestFixtures.syncMetadata,
        data: SyncData = TestFixtures.syncData
    ) {
        self.metadata = metadata
        self.data = data
    }

    func checkForUpdates(lastUpdated: Date?) async throws -> SyncMetadata {
        metadata
    }

    func fetchAllData(cachedDataProvider: @escaping () throws -> SyncData) async throws -> SyncData {
        data
    }
}
