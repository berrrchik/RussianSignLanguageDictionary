import Foundation

/// Root модель для JSON файла с данными о жестах
struct SignsData: Codable {
    /// Массив всех жестов
    let signs: [Sign]
    
    /// Массив всех категорий
    let categories: [Category]
    
    /// Общее количество жестов
    let totalSigns: Int
    
    /// Общее количество категорий
    let totalCategories: Int
    
    /// Версия данных
    let version: String?
    
    /// Дата последнего обновления данных
    let lastUpdated: String?
}

