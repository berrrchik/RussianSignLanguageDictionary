import Foundation

@MainActor
final class CategoriesViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var categories: [Category] = []
    @Published private(set) var state: ViewState = .idle
    
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
    
    init(signRepository: SignRepositoryProtocol) {
        self.signRepository = signRepository
    }
    
    // MARK: - Public Methods
    
    func loadCategories() async {
        state = .loading
        
        do {
            let loadedCategories = try await signRepository.loadCategories()
            categories = loadedCategories.sorted { $0.order < $1.order }
            state = .loaded
        } catch let error as SignRepositoryError {
            state = .error(errorMessage(for: error))
        } catch {
            state = .error("Произошла неизвестная ошибка")
        }
    }
    
    func refreshCategories() async {
        await loadCategories()
    }
    
    // MARK: - Private Methods
    
    private func errorMessage(for error: SignRepositoryError) -> String {
        return ErrorMessageMapper.message(for: error)
    }
}

