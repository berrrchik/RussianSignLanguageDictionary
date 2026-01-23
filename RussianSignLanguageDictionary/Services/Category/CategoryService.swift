import Foundation
import Combine
import os.log

@MainActor
enum CategoryService {
    // MARK: - Logger
    
    private static let logger = Logger(subsystem: "com.rsl.category", category: "CategoryService")
    // MARK: - Properties
    
    private static var categoriesById: [String: Category] = [:]
    private static var isLoaded = false
    private static var isLoading = false
    private static var loadTask: Task<Void, Never>?
    
    private static var dataSubscription: AnyCancellable?
    
    // MARK: - Public Methods
    
    static func loadCategories(from signRepository: SignRepositoryProtocol) async {
        guard !isLoaded else { return }
        
        if isLoading, let task = loadTask {
            await task.value
            return
        }
        
        isLoading = true
        
        loadTask = Task {
            do {
                let categories = try await signRepository.loadCategories()
                categoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
                isLoaded = true
                
                subscribeToUpdates(from: signRepository)
                
                logger.info("✅ Загружено \(categories.count) категорий")
            } catch {
                logger.error("❌ Ошибка загрузки категорий: \(ErrorMessageMapper.message(for: error))")
            }
            
            isLoading = false
            loadTask = nil
        }
        
        await loadTask?.value
    }
    
    private static func subscribeToUpdates(from signRepository: SignRepositoryProtocol) {
        guard let repo = signRepository as? SignRepository else { return }
        
        dataSubscription = repo.dataUpdatedPublisher
            .sink { updatedData in
                Task { @MainActor in
                    let updatedCategories = updatedData.categories.sorted { $0.order < $1.order }
                    categoriesById = Dictionary(uniqueKeysWithValues: updatedCategories.map { ($0.id, $0) })
                    
                    logger.info("🔄 Обновлено до \(updatedCategories.count) категорий")
                    
                    // Уведомляем об обновлении через NotificationCenter
                    NotificationCenter.default.post(name: .categoriesDidUpdate, object: nil)
                    NotificationCenter.default.post(name: .signsDidUpdate, object: nil)
                }
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
    
    static func allCategories() -> [Category] {
        return Array(categoriesById.values)
            .sorted { $0.order < $1.order }
    }
    
    static func reset() {
        categoriesById = [:]
        isLoaded = false
        isLoading = false
        loadTask?.cancel()
        loadTask = nil
        dataSubscription?.cancel()
        dataSubscription = nil
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let categoriesDidUpdate = Notification.Name("categoriesDidUpdate")
    static let signsDidUpdate = Notification.Name("signsDidUpdate")
}
