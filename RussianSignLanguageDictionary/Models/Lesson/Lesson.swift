import Foundation

struct Lesson: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let videoUrl: String
    let order: Int
    let createdAt: Date?
    let updatedAt: Date?
}
