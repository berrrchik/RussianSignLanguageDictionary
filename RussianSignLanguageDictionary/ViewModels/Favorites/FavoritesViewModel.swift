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
    @Published var sortOption: SortOption = .dateAddedDesc {
        didSet {
            sortFavorites()
        }
    }
    
    // MARK: - SortOption
    
    enum SortOption: String, CaseIterable {
        case dateAddedDesc = "Новые первыми"
        case dateAddedAsc = "Старые первыми"
        case alphabeticalAsc = "А → Я"
        case alphabeticalDesc = "Я → А"
    }
    
    // MARK: - Dependencies
    
    let favoritesRepository: FavoritesRepositoryProtocol
    private let signRepository: SignRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            favoritesRepository: container.resolve(FavoritesRepositoryProtocol.self),
            signRepository: container.resolve(SignRepositoryProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(
        favoritesRepository: FavoritesRepositoryProtocol,
        signRepository: SignRepositoryProtocol
    ) {
        self.favoritesRepository = favoritesRepository
        self.signRepository = signRepository

        signRepository.dataUpdatedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedData in
                self?.applyFavoriteData(
                    allSigns: updatedData.signs,
                    categories: updatedData.categories,
                    entries: favoritesRepository.getFavoriteEntries()
                )
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadFavorites() async {
        isLoading = true
        errorMessage = nil

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
        var snapshotFallbackCount = 0
        var missingIds: [String] = []

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
                snapshotFallbackCount += 1
                continue
            }

            missingIds.append(entry.signId)
        }

        favoriteSigns = loadedSigns
        categoryNamesById = resolvedCategoryNames
        offlineStatusBySignId = resolvedStatuses
        sortFavorites()

        if !missingIds.isEmpty {
            errorMessage = "Не удалось загрузить \(missingIds.count) жестов"
            logger.warning("⚠️ Missing signs: \(Set(missingIds))")
        } else if snapshotFallbackCount > 0 {
            errorMessage = "Часть избранного показана из сохранённых данных."
        } else {
            errorMessage = nil
        }
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

        favoriteSigns = loadedSigns
        categoryNamesById = resolvedCategoryNames
        offlineStatusBySignId = resolvedStatuses
        sortFavorites()

        if missingCount > 0 {
            errorMessage = "Часть избранного показана из сохранённых данных."
        } else {
            errorMessage = "Показаны сохранённые избранные данные."
        }

        return true
    }
    
    private func sortFavorites() {
        switch sortOption {
        case .dateAddedDesc:
            break
        case .dateAddedAsc:
            favoriteSigns.reverse()
        case .alphabeticalAsc:
            favoriteSigns.sort { $0.word < $1.word }
        case .alphabeticalDesc:
            favoriteSigns.sort { $0.word > $1.word }
        }
    }
}
