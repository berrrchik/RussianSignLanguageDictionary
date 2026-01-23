import Foundation

/// Модель синонима жеста
struct SignSynonym: Identifiable, Codable, Hashable {
    /// Уникальный идентификатор жеста-синонима
    let id: String
    
    /// Слово жеста-синонима
    let word: String
}
