import Foundation
import Combine
import os.log

@MainActor
final class CategoriesViewModel: ObservableObject {
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.rsl.categories", category: "CategoriesViewModel")
    // MARK: - Published Properties
    
    @Published private(set) var categories: [Category] = []
    @Published private(set) var state: ScreenLoadState = .idle

    // MARK: - Dependencies
    
    private let signRepository: SignRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            signRepository: container.resolve(SignRepositoryProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(signRepository: SignRepositoryProtocol) {
        self.signRepository = signRepository

        signRepository.dataUpdatedPublisher
            .sink { [weak self] updatedData in
                Task { @MainActor [weak self] in
                    self?.applyCategories(updatedData.categories)
                }
            }
            .store(in: &cancellables)

    }
    
    // MARK: - Public Methods
    
    func loadCategories() async {
        state = .loading
        
        do {
            let loadedCategories = try await signRepository.loadCategories()
            applyCategories(loadedCategories)
            state = .loaded
        } catch let error as SignRepositoryError {
            state = .error(errorMessage(for: error))
        } catch {
            state = .error(ErrorMessageMapper.message(for: error))
        }
    }
    
    func refreshCategories() async {
        await loadCategories()
    }
    
    // MARK: - Private Methods

    private func applyCategories(_ categories: [Category]) {
        self.categories = CategoryDisplayDataHelper.sortedCategories(categories)
        state = .loaded
        logger.info("🔄 UI обновлён (\(self.categories.count) категорий)")
    }
    
    private func errorMessage(for error: SignRepositoryError) -> String {
        return ErrorMessageMapper.message(for: error)
    }
}
