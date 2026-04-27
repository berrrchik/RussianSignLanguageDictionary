import Foundation
import Combine
import os.log

@MainActor
final class FavoritesViewModel: ObservableObject {
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.rsl.favorites", category: "FavoritesViewModel")
    // MARK: - Published Properties
    
    @Published private(set) var favoriteSigns: [Sign] = []
    @Published private(set) var categoryNamesById: [String: String] = [:]
    @Published private(set) var offlineStatusBySignId: [String: FavoriteOfflineStatus] = [:]
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    // MARK: - Dependencies
    
    let favoritesRepository: FavoritesRepositoryProtocol
    private let signRepository: SignRepositoryProtocol
    private let videoRepository: VideoRepositoryProtocol
    private let networkMonitor: NetworkMonitorProtocol
    private var cancellables = Set<AnyCancellable>()
    private var retryTask: Task<Void, Never>?
    
    // MARK: - Init
    
    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            favoritesRepository: container.resolve(FavoritesRepositoryProtocol.self),
            signRepository: container.resolve(SignRepositoryProtocol.self),
            videoRepository: container.resolve(VideoRepositoryProtocol.self),
            networkMonitor: container.resolve(NetworkMonitorProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(
        favoritesRepository: FavoritesRepositoryProtocol,
        signRepository: SignRepositoryProtocol,
        videoRepository: VideoRepositoryProtocol,
        networkMonitor: NetworkMonitorProtocol
    ) {
        self.favoritesRepository = favoritesRepository
        self.signRepository = signRepository
        self.videoRepository = videoRepository
        self.networkMonitor = networkMonitor

        signRepository.dataUpdatedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedData in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.favoritesRepository.reconcileOfflineState()
                    let entries = self.favoritesRepository.getFavoriteEntries()
                    self.applyFavoriteData(
                        allSigns: updatedData.signs,
                        categories: updatedData.categories,
                        entries: entries
                    )
                }
            }
            .store(in: &cancellables)

        networkMonitor.connectionRestoredPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.retryFailedOfflinePreparation()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadFavorites() async {
        isLoading = true
        errorMessage = nil

        await favoritesRepository.reconcileOfflineState()
        let entries = favoritesRepository.getFavoriteEntries()

        guard !entries.isEmpty else {
            favoriteSigns = []
            categoryNamesById = [:]
            offlineStatusBySignId = [:]
            isLoading = false
            return
        }

        do {
            async let loadedSignsTask = signRepository.loadAllSigns()
            async let loadedCategoriesTask = signRepository.loadCategories()
            let (allSigns, categories) = try await (loadedSignsTask, loadedCategoriesTask)
            applyFavoriteData(allSigns: allSigns, categories: categories, entries: entries)
        } catch {
            if applySnapshotFallback(entries: entries) {
                logger.warning("⚠️ Основная загрузка избранного не удалась, показаны snapshot данные")
            } else {
                errorMessage = ErrorMessageMapper.message(for: error)
                logger.error("❌ Failed to load all signs: \(error.localizedDescription)")
            }
        }

        isLoading = false
    }
    
    func removeFavorite(signId: String) {
        favoritesRepository.removeFavorite(signId: signId)
        favoriteSigns.removeAll { $0.id == signId }
        offlineStatusBySignId.removeValue(forKey: signId)
        if favoriteSigns.isEmpty {
            errorMessage = nil
        }
    }
    
    func clearAllFavorites() {
        retryTask?.cancel()
        favoritesRepository.clearAllFavorites()
        favoriteSigns = []
        categoryNamesById = [:]
        offlineStatusBySignId = [:]
        errorMessage = nil
    }
    
    func isFavorite(signId: String) -> Bool {
        return favoritesRepository.isFavorite(signId: signId)
    }
    
    // MARK: - Computed Properties
    
    var groupedFavorites: [SearchViewModel.SignSection] {
        SignGroupingHelper.groupByFirstLetter(favoriteSigns)
    }

    func offlineStatus(for signId: String) -> FavoriteOfflineStatus? {
        offlineStatusBySignId[signId]
    }
    
    // MARK: - Private Methods

    private func applyFavoriteData(allSigns: [Sign], categories: [Category], entries: [FavoriteEntry]) {
        let signsById = Dictionary(uniqueKeysWithValues: allSigns.map { ($0.id, $0) })
        let categoryNames = CategoryDisplayDataHelper.categoryNamesById(
            from: CategoryDisplayDataHelper.sortedCategories(categories)
        )
        var loadedSigns: [Sign] = []
        var resolvedCategoryNames: [String: String] = [:]
        var resolvedStatuses: [String: FavoriteOfflineStatus] = [:]
        var removedIds: [String] = []

        for entry in entries {
            resolvedStatuses[entry.signId] = entry.offlineStatus

            if let liveSign = signsById[entry.signId] {
                loadedSigns.append(liveSign)
                resolvedCategoryNames[liveSign.categoryId] = CategoryDisplayDataHelper.name(
                    for: liveSign.categoryId,
                    in: categoryNames
                )
                favoritesRepository.updateFavoriteSnapshot(
                    sign: liveSign,
                    categoryName: CategoryDisplayDataHelper.name(for: liveSign.categoryId, in: categoryNames)
                )
                continue
            }

            favoritesRepository.removeFavorite(signId: entry.signId)
            resolvedStatuses.removeValue(forKey: entry.signId)
            removedIds.append(entry.signId)
        }

        favoriteSigns = loadedSigns.sorted { $0.word < $1.word }
        categoryNamesById = resolvedCategoryNames
        offlineStatusBySignId = resolvedStatuses

        if !removedIds.isEmpty {
            logger.warning("⚠️ Removed missing favorites from local storage: \(Set(removedIds))")
        }
        errorMessage = nil
    }

    private func applySnapshotFallback(entries: [FavoriteEntry]) -> Bool {
        var loadedSigns: [Sign] = []
        var resolvedCategoryNames: [String: String] = [:]
        var resolvedStatuses: [String: FavoriteOfflineStatus] = [:]
        var missingCount = 0

        for entry in entries {
            resolvedStatuses[entry.signId] = entry.offlineStatus

            guard let snapshot = entry.snapshot else {
                missingCount += 1
                continue
            }

            loadedSigns.append(snapshot.sign)
            resolvedCategoryNames[snapshot.sign.categoryId] = snapshot.categoryName
        }

        guard !loadedSigns.isEmpty else {
            return false
        }

        favoriteSigns = loadedSigns.sorted { $0.word < $1.word }
        categoryNamesById = resolvedCategoryNames
        offlineStatusBySignId = resolvedStatuses

        errorMessage = nil

        return true
    }

    private func retryFailedOfflinePreparation() {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            await self?.performRetryFailedOfflinePreparation()
        }
    }

    private func performRetryFailedOfflinePreparation() async {
        guard await networkMonitor.checkConnection() else { return }

        await favoritesRepository.reconcileOfflineState()
        let failedEntries = favoritesRepository.failedFavoriteEntries()

        guard !failedEntries.isEmpty else { return }

        for entry in failedEntries {
            guard !Task.isCancelled else { return }
            guard favoritesRepository.isFavorite(signId: entry.signId) else { continue }

            if let snapshot = favoritesRepository.cachedFavoriteSnapshot(signId: entry.signId) {
                await prepareOfflineMedia(for: snapshot.sign, categoryName: snapshot.categoryName)
                continue
            }

            do {
                guard let liveSign = try await signRepository.getSign(byId: entry.signId) else { continue }
                let categoryName = categoryNamesById[liveSign.categoryId] ?? liveSign.categoryId.capitalized
                favoritesRepository.updateFavoriteSnapshot(sign: liveSign, categoryName: categoryName)
                await prepareOfflineMedia(for: liveSign, categoryName: categoryName)
            } catch {
                logger.warning("⚠️ Не удалось восстановить snapshot для retry \(entry.signId): \(error.localizedDescription)")
            }
        }

        if favoritesRepository.failedFavoriteEntries().isEmpty, !favoriteSigns.isEmpty {
            errorMessage = nil
        }
    }

    private func prepareOfflineMedia(for sign: Sign, categoryName: String) async {
        guard favoritesRepository.isFavorite(signId: sign.id) else { return }

        let requiredVideoIds = sign.videosArray.map(\.id)
        favoritesRepository.updateFavoriteSnapshot(sign: sign, categoryName: categoryName)

        if requiredVideoIds.isEmpty {
            favoritesRepository.updateOfflineStatus(
                signId: sign.id,
                status: .readyOffline,
                downloadedVideoIds: [],
                requiredVideoIds: []
            )
            offlineStatusBySignId[sign.id] = .readyOffline
            return
        }

        var downloadedVideoIds: [Int] = []

        for video in sign.videosArray {
            guard !Task.isCancelled else { return }

            do {
                _ = try await videoRepository.getVideoURL(for: video, useFavoritesCache: true)
                downloadedVideoIds.append(video.id)
            } catch {
                favoritesRepository.updateOfflineStatus(
                    signId: sign.id,
                    status: .failed,
                    downloadedVideoIds: downloadedVideoIds,
                    requiredVideoIds: requiredVideoIds
                )
                offlineStatusBySignId[sign.id] = .failed
                logger.warning("⚠️ Retry офлайн-подготовки не удался для \(sign.id): \(error.localizedDescription)")
                return
            }
        }

        favoritesRepository.updateOfflineStatus(
            signId: sign.id,
            status: .readyOffline,
            downloadedVideoIds: downloadedVideoIds,
            requiredVideoIds: requiredVideoIds
        )
        offlineStatusBySignId[sign.id] = .readyOffline
    }
}
