import Foundation
import Combine
import os.log

/// Сервис для работы с категориями жестов
/// Реализует кеширование категорий и подписку на обновления
@MainActor
final class CategoryService: CategoryServiceProtocol {
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.rsl.category", category: "CategoryService")
    
    // MARK: - Dependencies
    
    private let signRepository: SignRepositoryProtocol
    
    // MARK: - Properties
    
    private var categoriesById: [String: Category] = [:]
    private var isLoaded = false
    private var isLoading = false
    private var loadTask: Task<Void, Never>?
    
    private var dataSubscription: AnyCancellable?
    
    // MARK: - Initialization
    
    /// Инициализатор с внедрением зависимостей
    /// - Parameter signRepository: Репозиторий для загрузки категорий
    init(signRepository: SignRepositoryProtocol) {
        self.signRepository = signRepository
    }
    
    // MARK: - CategoryServiceProtocol
    
    func loadCategories() async {
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
                
                subscribeToUpdates()
                
                logger.info("✅ Загружено \(categories.count) категорий")
            } catch {
                logger.error("❌ Ошибка загрузки категорий: \(ErrorMessageMapper.message(for: error))")
            }
            
            isLoading = false
            loadTask = nil
        }
        
        await loadTask?.value
    }
    
    private func subscribeToUpdates() {
        guard let repo = signRepository as? SignRepository else { return }
        
        dataSubscription = repo.dataUpdatedPublisher
            .sink { [weak self] updatedData in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    let updatedCategories = updatedData.categories.sorted { $0.order < $1.order }
                    self.categoriesById = Dictionary(uniqueKeysWithValues: updatedCategories.map { ($0.id, $0) })
                    
                    self.logger.info("🔄 Обновлено до \(updatedCategories.count) категорий")
                    
                    // Уведомляем об обновлении через NotificationCenter
                    NotificationCenter.default.post(name: .categoriesDidUpdate, object: nil)
                    NotificationCenter.default.post(name: .signsDidUpdate, object: nil)
                }
            }
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
        return Array(categoriesById.values)
            .sorted { $0.order < $1.order }
    }
    
    func reset() {
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
