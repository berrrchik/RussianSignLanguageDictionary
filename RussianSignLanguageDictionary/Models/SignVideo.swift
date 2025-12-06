import Foundation

/// Модель видео для жеста
struct SignVideo: Identifiable, Codable, Hashable {
    /// Уникальный идентификатор видео
    let id: Int
    
    /// URL видео файла
    let url: String
    
    /// Описание контекста видео
    let contextDescription: String
    
    /// Порядок отображения видео
    let order: Int
    
    /// Дата создания (опционально, из API)
    let createdAt: Date?
    
    /// Дата обновления (опционально, из API)
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, url, order
        case contextDescription = "context_description"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
