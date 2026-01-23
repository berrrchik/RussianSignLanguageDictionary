import Foundation

/// Утилита для группировки жестов по первой букве
enum SignGroupingHelper {
    /// Группирует жесты по первой букве слова
    /// - Parameter signs: Массив жестов для группировки
    /// - Parameter sortOrder: Порядок сортировки (по умолчанию А-Я)
    /// - Returns: Массив секций, отсортированных по буквам
    static func groupByFirstLetter(
        _ signs: [Sign],
        sortOrder: SearchViewModel.SortOrder = .ascending
    ) -> [SearchViewModel.SignSection] {
        // Сортировка
        let sorted = signs.sorted { sign1, sign2 in
            let comparison = sign1.word.localizedCompare(sign2.word)
            return sortOrder == .ascending 
                ? comparison == .orderedAscending 
                : comparison == .orderedDescending
        }
        
        // Группировка по первой букве
        let grouped = Dictionary(grouping: sorted) { sign -> String in
            let firstChar = sign.word.uppercased().first ?? "#"
            return firstChar.isLetter ? String(firstChar) : "#"
        }
        
        // Преобразование в массив секций и сортировка
        return grouped.map { letter, signs in
            SearchViewModel.SignSection(id: letter, letter: letter, signs: signs)
        }
        .sorted { section1, section2 in
            // Секция "#" всегда в конце (независимо от порядка сортировки)
            if section1.letter == "#" { return false }
            if section2.letter == "#" { return true }
            // Сортировка секций по буквам
            let comparison = section1.letter.localizedCompare(section2.letter)
            return sortOrder == .ascending 
                ? comparison == .orderedAscending 
                : comparison == .orderedDescending
        }
        .filter { !$0.signs.isEmpty } // Убрать пустые секции
    }
}
