import Foundation

protocol LessonRepositoryProtocol: Sendable {
    func loadAllLessons() async throws -> [Lesson]
    func getLesson(byId id: String) async throws -> Lesson?
    func getLessons() async throws -> [Lesson]
}
