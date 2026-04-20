import Foundation

enum CategoryDisplayDataHelper {
    static func sortedCategories(_ categories: [Category]) -> [Category] {
        categories.sorted { $0.order < $1.order }
    }

    static func categoryNamesById(from categories: [Category]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
    }

    static func name(for categoryId: String, in categoryNamesById: [String: String]) -> String {
        categoryNamesById[categoryId] ?? categoryId.capitalized
    }
}
