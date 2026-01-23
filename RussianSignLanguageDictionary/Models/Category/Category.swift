import Foundation

/// Модель категории жестов
struct Category: Identifiable, Codable, Hashable {
    /// Уникальный идентификатор категории
    let id: String
    
    /// Название категории
    let name: String
    
    /// Порядковый номер категории (1-24)
    let order: Int
    
    /// Количество жестов в категории (вычисляется на сервере, всегда присутствует)
    let signCount: Int
    
    /// SF Symbol иконка (опционально)
    let icon: String?
    
    /// Цвет категории в hex формате (опционально)
    let color: String?
    
    /// Дата создания (опционально, из API)
    let createdAt: Date?
    
    /// Дата обновления (опционально, из API)
    let updatedAt: Date?
}

