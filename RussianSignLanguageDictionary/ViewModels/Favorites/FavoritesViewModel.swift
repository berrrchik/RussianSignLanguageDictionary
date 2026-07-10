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

    private let favoritesRepository: FavoritesRepositoryProtocol
    private let signRepository: SignRepositoryProtocol
    private let offlineRetryCoordinator: FavoritesOfflineRetryCoordinator
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            favoritesRepository: container.resolve(FavoritesRepositoryProtocol.self),
            signRepository: container.resolve(SignRepositoryProtocol.self),
            offlinePreparationService: container.resolve(OfflinePreparationServiceProtocol.self),
            networkMonitor: container.resolve(NetworkMonitorProtocol.self)
        )
    }

    /// Полный init для тестов и preview (constructor injection)
    init(
        favoritesRepository: FavoritesRepositoryProtocol,
        signRepository: SignRepositoryProtocol,
        offlinePreparationService: OfflinePreparationServiceProtocol,
        networkMonitor: NetworkMonitorProtocol
    ) {
        self.favoritesRepository = favoritesRepository
        self.signRepository = signRepository
        self.offlineRetryCoordinator = FavoritesOfflineRetryCoordinator(
            favoritesRepository: favoritesRepository,
            signRepository: signRepository,
            offlinePreparationService: offlinePreparationService,
            networkMonitor: networkMonitor
        )

        signRepository.dataUpdatedPublisher
            .sink { [weak self] updatedData in
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
            .sink { [weak self] in
                Task { @MainActor [weak self] in
                    self?.retryOfflinePreparationNow()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func loadFavorites() async {
        isLoading = true
        errorMessage = nil
        var shouldScheduleOfflinePreparationRetry = false

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
            shouldScheduleOfflinePreparationRetry = true
        } catch {
            if applySnapshotFallback(entries: entries) {
                logger.warning("⚠️ Основная загрузка избранного не удалась, показаны snapshot данные")
                shouldScheduleOfflinePreparationRetry = true
            } else {
                errorMessage = ErrorMessageMapper.message(for: error)
                logger.error("❌ Failed to load all signs: \(error.localizedDescription)")
            }
        }

        isLoading = false

        if shouldScheduleOfflinePreparationRetry {
            offlineRetryCoordinator.scheduleRetryIfNeeded(
                categoryName: { [weak self] categoryId in self?.resolvedCategoryName(for: categoryId) ?? categoryId },
                onStatusUpdate: { [weak self] signId, status in self?.offlineStatusBySignId[signId] = status },
                onAllResolved: { [weak self] in self?.clearErrorIfFavoritesPresent() }
            )
        }
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
        offlineRetryCoordinator.cancel()
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
        var snapshotFallbackIds: [String] = []

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

            if let snapshot = entry.snapshot {
                loadedSigns.append(snapshot.sign)
                resolvedCategoryNames[snapshot.sign.categoryId] = snapshot.categoryName
                snapshotFallbackIds.append(entry.signId)
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
        if !snapshotFallbackIds.isEmpty {
            logger.warning("⚠️ Missing live signs rendered from stored snapshots: \(Set(snapshotFallbackIds))")
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

        if missingCount > 0 {
            logger.warning("⚠️ Favorites without a cached snapshot skipped during fallback: \(missingCount)")
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

    private func retryOfflinePreparationNow() {
        offlineRetryCoordinator.retryNow(
            categoryName: { [weak self] categoryId in self?.resolvedCategoryName(for: categoryId) ?? categoryId },
            onStatusUpdate: { [weak self] signId, status in self?.offlineStatusBySignId[signId] = status },
            onAllResolved: { [weak self] in self?.clearErrorIfFavoritesPresent() }
        )
    }

    private func resolvedCategoryName(for categoryId: String) -> String {
        categoryNamesById[categoryId] ?? categoryId.capitalized
    }

    private func clearErrorIfFavoritesPresent() {
        guard !favoriteSigns.isEmpty else { return }
        errorMessage = nil
    }
}
