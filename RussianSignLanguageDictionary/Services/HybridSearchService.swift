import Foundation
import os.log

/// Сервис для гибридного поиска: текстовый поиск + SBERT семантический поиск
final class HybridSearchService {
    // MARK: - Properties
    
    private let baseURL: URL
    private let sbertService: SBERTSearchService
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
        networkMonitor: NetworkMonitorProtocol = NetworkMonitor()
    ) {
        self.baseURL = baseURL
        self.allSigns = signs
        self.networkMonitor = networkMonitor
        self.sbertService = SBERTSearchService(baseURL: baseURL)
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
        
        var results: [Sign] = []
        let lowercasedQuery = trimmedQuery.lowercased()
        
        // 1. Точное совпадение (текстовый поиск)
        let exactMatches = allSigns.filter { sign in
            sign.word.lowercased() == lowercasedQuery
        }
        results.append(contentsOf: exactMatches.prefix(limit))
        
        logger.info("🔍 Точных совпадений: \(exactMatches.count)")
        
        // Если нашли достаточно точных совпадений, возвращаем их
        if results.count >= limit {
            return Array(results.prefix(limit))
        }
        
        // 2. SBERT семантический поиск (только если есть интернет)
        let isConnected = await networkMonitor.checkConnection()
        if isConnected {
            do {
                let minSimilarity = useHighQualityThreshold 
                    ? Constants.highQualityMinSimilarity 
                    : Constants.defaultMinSimilarity
                
                let sbertResults = try await sbertService.search(
                    query: trimmedQuery,
                    limit: limit - results.count,
                    minSimilarity: minSimilarity
                )
                
                logger.info("🔍 SBERT результатов: \(sbertResults.count)")
                
                // Маппинг результатов обратно к жестам
                let sbertSigns = sbertResults.compactMap { result in
                    allSigns.first { $0.id == result.id }
                }
                
                // Исключаем уже найденные
                let newResults = sbertSigns.filter { result in
                    !results.contains { $0.id == result.id }
                }
                results.append(contentsOf: newResults)
                
            } catch {
                logger.warning("⚠️ SBERT поиск не удался: \(error.localizedDescription)")
                // Продолжаем с текстовым поиском как fallback
            }
        } else {
            logger.info("📴 Нет интернета, пропускаем SBERT поиск")
        }
        
        // 3. Fallback: текстовый поиск по частичному совпадению
        if results.count < limit {
            let textMatches = allSigns.filter { sign in
                let wordMatch = sign.word.lowercased().contains(lowercasedQuery)
                let keywordsMatch = (sign.keywords ?? []).contains { keyword in
                    keyword.lowercased().contains(lowercasedQuery)
                }
                let isNotAlreadyFound = !results.contains { $0.id == sign.id }
                
                return (wordMatch || keywordsMatch) && isNotAlreadyFound
            }
            
            // Сортировка текстовых результатов по релевантности:
            // 1. Совпадения в начале слова (выше приоритет)
            // 2. Совпадения в середине слова
            // 3. Совпадения в keywords
            let sortedTextMatches = textMatches.sorted { sign1, sign2 in
                let word1 = sign1.word.lowercased()
                let word2 = sign2.word.lowercased()
                
                // Проверяем, начинается ли слово с запроса
                let startsWith1 = word1.hasPrefix(lowercasedQuery)
                let startsWith2 = word2.hasPrefix(lowercasedQuery)
                
                if startsWith1 != startsWith2 {
                    return startsWith1 // Начинающиеся с запроса идут первыми
                }
                
                // Если оба начинаются или оба не начинаются, сортируем по позиции вхождения
                let position1 = word1.range(of: lowercasedQuery)?.lowerBound.utf16Offset(in: word1) ?? Int.max
                let position2 = word2.range(of: lowercasedQuery)?.lowerBound.utf16Offset(in: word2) ?? Int.max
                
                if position1 != position2 {
                    return position1 < position2 // Раньше в слове = выше приоритет
                }
                
                // Если позиции одинаковые, сортируем по алфавиту
                return word1 < word2
            }
            
            logger.info("🔍 Текстовых совпадений: \(sortedTextMatches.count)")
            results.append(contentsOf: sortedTextMatches.prefix(limit - results.count))
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
        
        let lowercasedQuery = trimmedQuery.lowercased()
        
        return allSigns.filter { sign in
            let wordMatch = sign.word.lowercased().contains(lowercasedQuery)
            let keywordsMatch = (sign.keywords ?? []).contains { keyword in
                keyword.lowercased().contains(lowercasedQuery)
            }
            return wordMatch || keywordsMatch
        }
        .prefix(limit)
        .map { $0 }
    }
}
