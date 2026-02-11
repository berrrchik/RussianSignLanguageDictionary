import Foundation

/// Протокол для работы с категориями жестов
@MainActor
protocol CategoryServiceProtocol {
    /// Загружает категории из репозитория
    func loadCategories() async
    
    /// Возвращает название категории по ID
    func name(for categoryId: String) -> String
    
    /// Возвращает категорию по ID
    func category(for categoryId: String) -> Category?
    
    /// Возвращает иконку категории по ID
    func icon(for categoryId: String) -> String?
    
    /// Возвращает цвет категории по ID
    func color(for categoryId: String) -> String?
    
    /// Возвращает все категории
    func allCategories() -> [Category]
}
