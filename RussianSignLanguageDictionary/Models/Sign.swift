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
    let category: String
    
    /// Массив видео для жеста (новая структура из API)
    let videos: [SignVideo]?
    
    /// Массив синонимов жеста (опционально)
    let synonyms: [SignSynonym]?
    
    /// Эмбеддинги для семантического поиска (RuBERT) - опционально
    let embeddings: [Double]?
    
    // MARK: - Обратная совместимость (для старых JSON данных)
    
    /// Идентификатор видео файла (устаревшее, используется для обратной совместимости)
    let videoId: String?
    
    /// Путь к видео в Supabase Storage (устаревшее)
    let supabaseStoragePath: String?
    
    /// Публичный URL видео в Supabase Storage (устаревшее)
    let supabaseUrl: String?
    
    /// Ключевые слова для поиска (устаревшее, может быть пустым)
    let keywords: [String]?
    
    /// Метаданные видео файла (устаревшее)
    let metadata: SignMetadata?
    
    // MARK: - CodingKeys
    
    enum CodingKeys: String, CodingKey {
        case id, word, description, videos, synonyms, embeddings
        case category = "category_id"
        case videoId = "video_id"
        case supabaseStoragePath = "supabase_storage_path"
        case supabaseUrl = "supabase_url"
        case keywords
        case metadata
    }
    
    // MARK: - Computed Properties (для обратной совместимости)
    
    /// Получает первое видео из массива или nil
    var firstVideo: SignVideo? {
        return videos?.first
    }
    
    /// Получает URL первого видео для обратной совместимости
    var primaryVideoURL: String? {
        return videos?.first?.url ?? supabaseUrl
    }
    
    /// Получает массив видео или пустой массив
    var videosArray: [SignVideo] {
        return videos ?? []
    }
}

