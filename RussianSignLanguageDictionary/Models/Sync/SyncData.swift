import Foundation

struct SyncData: Codable {
    let categories: [Category]
    let signs: [Sign]
    let lessons: [Lesson]
    let lastUpdated: Date
}
