import Foundation

protocol LessonRepositoryProtocol {
    func loadAllLessons() async throws -> [Lesson]
    func getLesson(byId id: String) async throws -> Lesson?
    func getLessons() async throws -> [Lesson]
}
