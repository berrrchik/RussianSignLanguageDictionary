import Foundation

/// Модель результата SBERT поиска
struct SBERTSearchResult: Codable, Identifiable {
    /// Идентификатор жеста
    let id: String
    
    /// Слово жеста
    let word: String
    
    /// Значение сходства (0.0 - 1.0)
    let similarity: Double
}

/// Модель ответа от SBERT API
struct SBERTSearchResponse: Codable {
    /// Успешность запроса
    let success: Bool
    
    /// Данные ответа (если успешно)
    let data: SBERTSearchData?
    
    /// Ошибка (если запрос неуспешен)
    let error: APIError?
    
    /// Структура данных ответа
    struct SBERTSearchData: Codable {
        /// Текст запроса
        let query: String
        
        /// Используемая модель
        let model: String
        
        /// Общее количество найденных результатов
        let totalFound: Int
        
        /// Массив результатов поиска
        let results: [SBERTSearchResult]
        
        enum CodingKeys: String, CodingKey {
            case query
            case model
            case totalFound = "total_found"
            case results
        }
    }
    
    /// Структура ошибки API
    struct APIError: Codable {
        /// Код ошибки
        let code: String
        
        /// Сообщение об ошибке
        let message: String
    }
}
