import Foundation

/// Утилита для текстового поиска по жестам
///
/// Единый источник логики текстового фильтрования жестов.
/// Используется в `SignRepository.searchSigns()` и `HybridSearchService.performTextSearch()`.
enum SignTextSearchHelper {
    
    /// Фильтрует жесты по текстовому запросу (поиск по слову и ключевым словам)
    /// - Parameters:
    ///   - signs: Массив жестов для поиска
    ///   - query: Поисковый запрос (непустой, уже trimmed)
    ///   - includeDescription: Искать ли в описании жеста (по умолчанию false)
    /// - Returns: Массив найденных жестов
    static func filterSigns(
        _ signs: [Sign],
        query: String,
        includeDescription: Bool = false
    ) -> [Sign] {
        let lowercasedQuery = query.lowercased()
        
        return signs.filter { sign in
            sign.word.lowercased().contains(lowercasedQuery) ||
            (sign.keywords ?? []).contains { $0.lowercased().contains(lowercasedQuery) } ||
            (includeDescription && sign.description.lowercased().contains(lowercasedQuery))
        }
    }
    
    /// Фильтрует жесты и исключает уже найденные результаты
    /// - Parameters:
    ///   - signs: Массив жестов для поиска
    ///   - query: Поисковый запрос (непустой, уже trimmed)
    ///   - excludingIds: Set ID жестов, которые нужно исключить
    /// - Returns: Массив найденных жестов
    static func filterSigns(
        _ signs: [Sign],
        query: String,
        excludingIds: Set<String>
    ) -> [Sign] {
        let lowercasedQuery = query.lowercased()
        
        return signs.filter { sign in
            guard !excludingIds.contains(sign.id) else { return false }
            
            return sign.word.lowercased().contains(lowercasedQuery) ||
                (sign.keywords ?? []).contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
    
    /// Сортирует текстовые результаты по релевантности:
    /// 1. Совпадения в начале слова (выше приоритет)
    /// 2. Совпадения в середине слова
    /// 3. Совпадения в keywords
    /// - Parameters:
    ///   - signs: Массив жестов для сортировки
    ///   - query: Поисковый запрос
    /// - Returns: Отсортированный массив
    static func sortByRelevance(_ signs: [Sign], query: String) -> [Sign] {
        let lowercasedQuery = query.lowercased()
        
        return signs.sorted { sign1, sign2 in
            let word1 = sign1.word.lowercased()
            let word2 = sign2.word.lowercased()
            
            // Проверяем, начинается ли слово с запроса
            let startsWith1 = word1.hasPrefix(lowercasedQuery)
            let startsWith2 = word2.hasPrefix(lowercasedQuery)
            
            if startsWith1 != startsWith2 {
                return startsWith1
            }
            
            // Сортируем по позиции вхождения
            let position1 = word1.range(of: lowercasedQuery)?.lowerBound.utf16Offset(in: word1) ?? Int.max
            let position2 = word2.range(of: lowercasedQuery)?.lowerBound.utf16Offset(in: word2) ?? Int.max
            
            if position1 != position2 {
                return position1 < position2
            }
            
            // Сортируем по алфавиту
            return word1 < word2
        }
    }
}
