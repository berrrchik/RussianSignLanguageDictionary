import Foundation

@MainActor
final class CategoryDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var signs: [Sign] = []
    @Published private(set) var state: ViewState = .idle
    
    // MARK: - Properties
    
    let category: Category
    
    // MARK: - ViewState
    
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }
    
    // MARK: - Dependencies
    
    private let signRepository: SignRepositoryProtocol
    
    // MARK: - Init
    
    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init(category: Category) {
        self.init(
            category: category,
            signRepository: DIContainer.shared.resolve(SignRepositoryProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(category: Category, signRepository: SignRepositoryProtocol) {
        self.category = category
        self.signRepository = signRepository
    }
    
    // MARK: - Public Methods
    
    /// Загружает жесты выбранной категории
    func loadSigns() async {
        state = .loading
        
        do {
            let loadedSigns = try await signRepository.getSigns(byCategory: category.id)
            signs = loadedSigns
            state = .loaded
        } catch let error as SignRepositoryError {
            state = .error(errorMessage(for: error))
        } catch {
            state = .error("Произошла неизвестная ошибка")
        }
    }
    
    // MARK: - Computed Properties
    
    var groupedSigns: [SearchViewModel.SignSection] {
        SignGroupingHelper.groupByFirstLetter(signs)
    }
    
    // MARK: - Private Methods
    
    private func errorMessage(for error: SignRepositoryError) -> String {
        return ErrorMessageMapper.message(for: error)
    }
}

