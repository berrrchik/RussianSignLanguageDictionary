import Foundation
import os.log

/// Сервис для гибридного поиска: текстовый поиск + SBERT семантический поиск
final class HybridSearchService {
    // MARK: - Properties
    
    private let baseURL: URL
    private let sbertService: SBERTSearchServiceProtocol
    private let allSigns: [Sign]
    private let networkMonitor: NetworkMonitorProtocol
    private let logger = Logger(subsystem: "com.rsl.HybridSearchService", category: "search")
    
    // MARK: - Constants
    
    private enum Constants {
        /// Минимальный порог сходства для SBERT поиска
        /// Повышен до 0.6 для более релевантных результатов
        /// 0.6-0.7: Умеренное сходство (связанные, но не идентичные понятия)
        static let defaultMinSimilarity: Double = 0.7
        
        /// Минимальный порог для высококачественных результатов
        /// 0.7-0.9: Похожие слова (синонимы, связанные понятия)
        static let highQualityMinSimilarity: Double = 0.8
    }
    
    // MARK: - Initialization
    
    /// Инициализатор гибридного сервиса поиска
    /// - Parameters:
    ///   - baseURL: Базовый URL API
    ///   - signs: Все жесты из локального кеша
    ///   - networkMonitor: Монитор сети для проверки доступности
    init(
        baseURL: URL = APIConfig.baseURL,
        signs: [Sign],
        networkMonitor: NetworkMonitorProtocol,
        sbertService: SBERTSearchServiceProtocol
    ) {
        self.baseURL = baseURL
        self.allSigns = signs
        self.networkMonitor = networkMonitor
        self.sbertService = sbertService
    }
    
    // MARK: - Public Methods
    
    /// Выполняет гибридный поиск: точное совпадение → SBERT поиск → текстовый поиск (fallback)
    /// - Parameters:
    ///   - query: Текстовый запрос
    ///   - limit: Максимальное количество результатов (по умолчанию 20)
    ///   - useHighQualityThreshold: Использовать высокий порог сходства для SBERT (по умолчанию false)
    /// - Returns: Массив жестов, отсортированных по релевантности
    func performHybridSearch(
        query: String,
        limit: Int = 20,
        useHighQualityThreshold: Bool = false
    ) async throws -> [Sign] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return allSigns
        }
        
        // 1. Точное совпадение
        var results = findExactMatches(query: trimmedQuery, limit: limit)
        guard results.count < limit else {
            return Array(results.prefix(limit))
        }
        
        // 2. SBERT семантический поиск
        let sbertResults = await findSBERTMatches(
            query: trimmedQuery,
            limit: limit - results.count,
            excludingIds: Set(results.map { $0.id }),
            useHighQualityThreshold: useHighQualityThreshold
        )
        results.append(contentsOf: sbertResults)
        
        // 3. Текстовый поиск (fallback)
        if results.count < limit {
            let textResults = findTextMatches(
                query: trimmedQuery,
                limit: limit - results.count,
                excludingIds: Set(results.map { $0.id })
            )
            results.append(contentsOf: textResults)
        }
        
        return Array(results.prefix(limit))
    }
    
    /// Выполняет только текстовый поиск (без SBERT)
    /// - Parameters:
    ///   - query: Текстовый запрос
    ///   - limit: Максимальное количество результатов
    /// - Returns: Массив жестов, найденных текстовым поиском
    func performTextSearch(query: String, limit: Int = 20) -> [Sign] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return allSigns
        }
        
        return Array(SignTextSearchHelper.filterSigns(allSigns, query: trimmedQuery).prefix(limit))
    }
    
    // MARK: - Private Search Steps
    
    /// Шаг 1: Поиск точных совпадений по слову
    private func findExactMatches(query: String, limit: Int) -> [Sign] {
        let lowercasedQuery = query.lowercased()
        let matches = allSigns.filter { $0.word.lowercased() == lowercasedQuery }
        logger.info("🔍 Точных совпадений: \(matches.count)")
        return Array(matches.prefix(limit))
    }
    
    /// Шаг 2: SBERT семантический поиск (только при наличии интернета)
    private func findSBERTMatches(
        query: String,
        limit: Int,
        excludingIds: Set<String>,
        useHighQualityThreshold: Bool
    ) async -> [Sign] {
        guard await networkMonitor.checkConnection() else {
            logger.info("📴 Нет интернета, пропускаем SBERT поиск")
            return []
        }
        
        do {
            let minSimilarity = useHighQualityThreshold
                ? Constants.highQualityMinSimilarity
                : Constants.defaultMinSimilarity
            
            let sbertResults = try await sbertService.search(
                query: query,
                limit: limit,
                minSimilarity: minSimilarity
            )
            
            logger.info("🔍 SBERT результатов: \(sbertResults.count)")
            
            return sbertResults.compactMap { result in
                guard !excludingIds.contains(result.id) else { return nil }
                return allSigns.first { $0.id == result.id }
            }
        } catch {
            logger.warning("⚠️ SBERT поиск не удался: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Шаг 3: Текстовый поиск по частичному совпадению с сортировкой по релевантности
    private func findTextMatches(
        query: String,
        limit: Int,
        excludingIds: Set<String>
    ) -> [Sign] {
        let textMatches = SignTextSearchHelper.filterSigns(allSigns, query: query, excludingIds: excludingIds)
        let sorted = SignTextSearchHelper.sortByRelevance(textMatches, query: query)
        logger.info("🔍 Текстовых совпадений: \(sorted.count)")
        return Array(sorted.prefix(limit))
    }
}
