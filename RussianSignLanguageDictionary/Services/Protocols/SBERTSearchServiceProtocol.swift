import Foundation

/// Протокол для выполнения SBERT семантического поиска
protocol SBERTSearchServiceProtocol {
    /// Выполняет SBERT семантический поиск жестов
    /// - Parameters:
    ///   - query: Текстовый запрос для поиска
    ///   - limit: Максимальное количество результатов (1-50, по умолчанию 10)
    ///   - minSimilarity: Минимальное значение сходства (0.0-1.0, по умолчанию 0.0)
    /// - Returns: Массив результатов поиска, отсортированных по сходству
    /// - Throws: SBERTSearchError при ошибках запроса
    func search(
        query: String,
        limit: Int,
        minSimilarity: Double
    ) async throws -> [SBERTSearchResult]
}
