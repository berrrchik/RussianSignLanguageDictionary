import Foundation

#if DEBUG
/// Mock реализация CategoryServiceProtocol для превью и тестов
@MainActor
final class MockCategoryService: CategoryServiceProtocol {
    // MARK: - Properties
    
    private let categories: [Category]
    private var categoriesById: [String: Category]
    
    // MARK: - Init
    
    init(categories: [Category] = Category.mockArray()) {
        self.categories = categories
        self.categoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }
    
    // MARK: - CategoryServiceProtocol
    
    func loadCategories() async {
        // В mock версии категории уже загружены
    }
    
    func name(for categoryId: String) -> String {
        return categoriesById[categoryId]?.name ?? categoryId.capitalized
    }
    
    func category(for categoryId: String) -> Category? {
        return categoriesById[categoryId]
    }
    
    func icon(for categoryId: String) -> String? {
        return categoriesById[categoryId]?.icon
    }
    
    func color(for categoryId: String) -> String? {
        return categoriesById[categoryId]?.color
    }
    
    func allCategories() -> [Category] {
        return Array(categoriesById.values).sorted { $0.order < $1.order }
    }
}

// MARK: - Shared Instances

extension MockCategoryService {
    /// Общий экземпляр для использования в Preview
    static let shared = MockCategoryService()
}
#endif
