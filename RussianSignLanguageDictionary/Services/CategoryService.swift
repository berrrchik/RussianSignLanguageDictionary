import Foundation

enum CategoryService {
    // MARK: - Properties
    
    private static var categoriesById: [String: Category] = [:]
    private static var isLoaded = false
    
    // MARK: - Public Methods
    
    @MainActor
    static func loadCategories(from signRepository: SignRepositoryProtocol) async {
        guard !isLoaded else { return }
        
        do {
            let categories = try await signRepository.loadCategories()
            categoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
            isLoaded = true
            #if DEBUG
            print("✅ CategoryService: Загружено \(categories.count) категорий")
            #endif
        } catch {
            #if DEBUG
            print("❌ CategoryService: Ошибка загрузки категорий: \(ErrorMessageMapper.message(for: error))")
            #endif
        }
    }
    
    static func name(for categoryId: String) -> String {
        return categoriesById[categoryId]?.name ?? categoryId.capitalized
    }
    
    static func category(for categoryId: String) -> Category? {
        return categoriesById[categoryId]
    }
    
    static func icon(for categoryId: String) -> String? {
        return categoriesById[categoryId]?.icon
    }

    static func color(for categoryId: String) -> String? {
        return categoriesById[categoryId]?.color
    }
}

