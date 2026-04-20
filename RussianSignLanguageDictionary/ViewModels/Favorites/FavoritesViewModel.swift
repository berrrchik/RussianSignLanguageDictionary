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
                    favoriteIds: favoritesRepository.getFavorites()
                )
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadFavorites() async {
        isLoading = true
        errorMessage = nil
        
        let favoriteIds = favoritesRepository.getFavorites()
        
        guard !favoriteIds.isEmpty else {
            favoriteSigns = []
            categoryNamesById = [:]
            isLoading = false
            return
        }
        
        do {
            async let loadedSignsTask = signRepository.loadAllSigns()
            async let loadedCategoriesTask = signRepository.loadCategories()
            let (allSigns, categories) = try await (loadedSignsTask, loadedCategoriesTask)
            applyFavoriteData(allSigns: allSigns, categories: categories, favoriteIds: favoriteIds)
        } catch {
            errorMessage = ErrorMessageMapper.message(for: error)
            logger.error("❌ Failed to load all signs: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func removeFavorite(signId: String) {
        favoritesRepository.removeFavorite(signId: signId)
        favoriteSigns.removeAll { $0.id == signId }
    }
    
    func clearAllFavorites() {
        favoritesRepository.clearAllFavorites()
        favoriteSigns = []
        categoryNamesById = [:]
    }
    
    func isFavorite(signId: String) -> Bool {
        return favoritesRepository.isFavorite(signId: signId)
    }
    
    // MARK: - Computed Properties
    
    var groupedFavorites: [SearchViewModel.SignSection] {
        SignGroupingHelper.groupByFirstLetter(favoriteSigns)
    }
    
    // MARK: - Private Methods

    private func applyFavoriteData(allSigns: [Sign], categories: [Category], favoriteIds: [String]) {
        let signsById = Dictionary(uniqueKeysWithValues: allSigns.map { ($0.id, $0) })
        let loadedSigns = favoriteIds.compactMap { signsById[$0] }

        favoriteSigns = loadedSigns
        categoryNamesById = CategoryDisplayDataHelper.categoryNamesById(
            from: CategoryDisplayDataHelper.sortedCategories(categories)
        )
        sortFavorites()

        let failedCount = favoriteIds.count - loadedSigns.count
        if failedCount > 0 {
            errorMessage = "Не удалось загрузить \(failedCount) жестов"
            let missingIds = Set(favoriteIds).subtracting(loadedSigns.map { $0.id })
            logger.warning("⚠️ Missing signs: \(missingIds)")
        } else {
            errorMessage = nil
        }
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
