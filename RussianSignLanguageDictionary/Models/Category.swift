import Foundation

/// Модель категории жестов
struct Category: Identifiable, Codable, Hashable {
    /// Уникальный идентификатор категории
    let id: String
    
    /// Название категории
    let name: String
    
    /// Порядковый номер категории (1-24)
    let order: Int
    
    /// Количество жестов в категории
    let signCount: Int
    
    /// SF Symbol иконка (опционально)
    let icon: String?
    
    /// Цвет категории в hex формате (опционально)
    let color: String?
}

