import Foundation
import Combine

@MainActor
final class CategoryDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var signs: [Sign] = []
    @Published private(set) var categoryNamesById: [String: String] = [:]
    @Published private(set) var state: ScreenLoadState = .idle

    // MARK: - Properties

    let category: Category

    // MARK: - Dependencies
    
    private let signRepository: SignRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init(category: Category) {
        let container = DIContainer.shared
        self.init(
            category: category,
            signRepository: container.resolve(SignRepositoryProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(category: Category, signRepository: SignRepositoryProtocol) {
        self.category = category
        self.signRepository = signRepository
        self.categoryNamesById = CategoryDisplayDataHelper.categoryNamesById(from: [category])

        signRepository.dataUpdatedPublisher
            .sink { [weak self] updatedData in
                Task { @MainActor [weak self] in
                    self?.applyLoadedData(
                        signs: updatedData.signs.filter { $0.categoryId == category.id },
                        categories: updatedData.categories
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Загружает жесты выбранной категории
    func loadSigns() async {
        state = .loading
        
        do {
            async let loadedSignsTask = signRepository.getSigns(byCategory: category.id)
            async let loadedCategoriesTask = signRepository.loadCategories()
            let (loadedSigns, loadedCategories) = try await (loadedSignsTask, loadedCategoriesTask)
            applyLoadedData(signs: loadedSigns, categories: loadedCategories)
        } catch let error as SignRepositoryError {
            state = .error(errorMessage(for: error))
        } catch {
            state = .error(ErrorMessageMapper.message(for: error))
        }
    }
    
    // MARK: - Computed Properties
    
    var groupedSigns: [SearchViewModel.SignSection] {
        SignGroupingHelper.groupByFirstLetter(signs)
    }
    
    // MARK: - Private Methods

    private func applyLoadedData(signs: [Sign], categories: [Category]) {
        self.signs = signs
        let sortedCategories = CategoryDisplayDataHelper.sortedCategories(categories)
        categoryNamesById = CategoryDisplayDataHelper.categoryNamesById(from: sortedCategories)
        state = .loaded
    }
    
    private func errorMessage(for error: SignRepositoryError) -> String {
        return ErrorMessageMapper.message(for: error)
    }
}
