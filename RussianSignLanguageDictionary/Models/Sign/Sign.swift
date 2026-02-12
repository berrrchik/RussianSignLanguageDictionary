import Foundation

/// Модель жеста РЖЯ (Русский Жестовый Язык)
struct Sign: Identifiable, Codable, Hashable {
    /// Уникальный идентификатор жеста
    let id: String
    
    /// Русское слово или фраза
    let word: String
    
    /// Описание жеста
    let description: String
    
    /// Идентификатор категории
    let categoryId: String
    
    /// Массив видео для жеста (новая структура из API)
    let videos: [SignVideo]?
    
    /// Массив синонимов жеста (опционально)
    let synonyms: [SignSynonym]?
    
    // MARK: - Computed Properties
    
    /// Получает первое видео из массива или nil
    var firstVideo: SignVideo? {
        return videos?.first
    }
    
    /// Получает URL первого видео
    var primaryVideoURL: String? {
        return videos?.first?.url
    }
    
    /// Получает массив видео или пустой массив
    var videosArray: [SignVideo] {
        return videos ?? []
    }
}

