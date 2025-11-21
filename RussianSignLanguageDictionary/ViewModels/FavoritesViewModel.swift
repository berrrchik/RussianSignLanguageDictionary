import Foundation

@MainActor
final class FavoritesViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var favoriteSigns: [Sign] = []
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
    
    // MARK: - Init
    
    init(
        favoritesRepository: FavoritesRepositoryProtocol,
        signRepository: SignRepositoryProtocol
    ) {
        self.favoritesRepository = favoritesRepository
        self.signRepository = signRepository
    }
    
    // MARK: - Public Methods
    
    func loadFavorites() async {
        isLoading = true
        errorMessage = nil
        
        let favoriteIds = favoritesRepository.getFavorites()
        
        guard !favoriteIds.isEmpty else {
            favoriteSigns = []
            isLoading = false
            return
        }
        
        do {

            let allSigns = try await signRepository.loadAllSigns()
            
            let signsById = Dictionary(uniqueKeysWithValues: allSigns.map { ($0.id, $0) })
            
            let loadedSigns = favoriteIds.compactMap { id in
                signsById[id]
            }
            
            favoriteSigns = loadedSigns
            sortFavorites()
            
            let failedCount = favoriteIds.count - loadedSigns.count
            if failedCount > 0 {
                errorMessage = "Не удалось загрузить \(failedCount) жестов"
                #if DEBUG
                let missingIds = Set(favoriteIds).subtracting(loadedSigns.map { $0.id })
                print("⚠️ FavoritesViewModel: Missing signs: \(missingIds)")
                #endif
            }
        } catch {
            errorMessage = ErrorMessageMapper.message(for: error)
            #if DEBUG
            print("❌ FavoritesViewModel: Failed to load all signs: \(error)")
            #endif
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
    }
    
    func isFavorite(signId: String) -> Bool {
        return favoritesRepository.isFavorite(signId: signId)
    }
    
    // MARK: - Private Methods
    
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

