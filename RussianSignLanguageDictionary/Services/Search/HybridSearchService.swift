import Foundation
import os.log

/// Сервис для гибридного поиска: текстовый поиск + SBERT семантический поиск
///
/// **Performance Monitoring**: Все этапы поиска отслеживаются через Firebase Performance Monitoring:
/// - `hybrid_search` - общий трейс гибридного поиска
/// - `search_exact_match` - поиск точных совпадений
/// - `search_sbert` - SBERT семантический поиск
/// - `search_text` - текстовый поиск по частичному совпадению
final class HybridSearchService: HybridSearchServiceProtocol, Sendable {
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
        baseURL: URL = APIConfig.apiBaseURL,
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
        
        let mainTrace = PerformanceService.startTrace("hybrid_search")
        PerformanceService.addAttribute(mainTrace, name: "query", value: trimmedQuery)
        PerformanceService.addAttribute(mainTrace, name: "limit", value: String(limit))
        PerformanceService.addAttribute(mainTrace, name: "high_quality", value: useHighQualityThreshold ? "true" : "false")
        defer { PerformanceService.stopTrace(mainTrace) }
        
        // 1. Точное совпадение
        var results = findExactMatches(query: trimmedQuery, limit: limit)
        guard results.count < limit else {
            PerformanceService.incrementMetric(mainTrace, name: "total_results", by: Int64(results.count))
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
        
        PerformanceService.incrementMetric(mainTrace, name: "total_results", by: Int64(results.count))
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
        let trace = PerformanceService.startTrace("search_exact_match")
        PerformanceService.addAttribute(trace, name: "query", value: query)
        defer { PerformanceService.stopTrace(trace) }
        
        let lowercasedQuery = query.lowercased()
        let matches = allSigns.filter { $0.word.lowercased() == lowercasedQuery }
        logger.info("🔍 Точных совпадений: \(matches.count)")
        
        let results = Array(matches.prefix(limit))
        PerformanceService.incrementMetric(trace, name: "results_count", by: Int64(results.count))
        return results
    }
    
    /// Шаг 2: SBERT семантический поиск (только при наличии интернета)
    private func findSBERTMatches(
        query: String,
        limit: Int,
        excludingIds: Set<String>,
        useHighQualityThreshold: Bool
    ) async -> [Sign] {
        let trace = PerformanceService.startTrace("search_sbert")
        PerformanceService.addAttribute(trace, name: "query", value: query)
        PerformanceService.addAttribute(trace, name: "limit", value: String(limit))
        PerformanceService.addAttribute(trace, name: "high_quality", value: useHighQualityThreshold ? "true" : "false")
        defer { PerformanceService.stopTrace(trace) }
        
        guard await networkMonitor.checkConnection() else {
            logger.info("📴 Нет интернета, пропускаем SBERT поиск")
            PerformanceService.addAttribute(trace, name: "error", value: "no_internet")
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
            
            let results: [Sign] = sbertResults.compactMap { result in
                guard !excludingIds.contains(result.id) else { return nil }
                return allSigns.first { $0.id == result.id }
            }
            
            PerformanceService.incrementMetric(trace, name: "results_count", by: Int64(results.count))
            return results
        } catch {
            logger.warning("⚠️ SBERT поиск не удался: \(error.localizedDescription)")
            PerformanceService.addAttribute(trace, name: "error", value: error.localizedDescription)
            return []
        }
    }
    
    /// Шаг 3: Текстовый поиск по частичному совпадению с сортировкой по релевантности
    private func findTextMatches(
        query: String,
        limit: Int,
        excludingIds: Set<String>
    ) -> [Sign] {
        let trace = PerformanceService.startTrace("search_text")
        PerformanceService.addAttribute(trace, name: "query", value: query)
        PerformanceService.addAttribute(trace, name: "limit", value: String(limit))
        defer { PerformanceService.stopTrace(trace) }
        
        let textMatches = SignTextSearchHelper.filterSigns(allSigns, query: query, excludingIds: excludingIds)
        let sorted = SignTextSearchHelper.sortByRelevance(textMatches, query: query)
        logger.info("🔍 Текстовых совпадений: \(sorted.count)")
        
        let results = Array(sorted.prefix(limit))
        PerformanceService.incrementMetric(trace, name: "results_count", by: Int64(results.count))
        return results
    }
}
