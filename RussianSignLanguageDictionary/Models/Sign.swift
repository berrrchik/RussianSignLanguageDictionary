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
    
    /// Идентификатор видео файла
    let videoId: String
    
    /// Путь к видео в Supabase Storage
    let supabaseStoragePath: String
    
    /// Публичный URL видео в Supabase Storage
    let supabaseUrl: String
    
    /// Ключевые слова для поиска
    let keywords: [String]
    
    /// Эмбеддинги для семантического поиска (RuBERT)
    let embeddings: [Double]
    
    /// Метаданные видео файла
    let metadata: SignMetadata
}

