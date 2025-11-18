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
    
    // MARK: - Private Methods
    
    private func errorMessage(for error: SignRepositoryError) -> String {
        return ErrorMessageMapper.message(for: error)
    }
}

