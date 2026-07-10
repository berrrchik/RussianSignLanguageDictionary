import Foundation

final class LessonRepository: LessonRepositoryProtocol {
    
    private let cacheService: CacheServiceProtocol

    init(cacheService: CacheServiceProtocol = CacheService()) {
        self.cacheService = cacheService
    }
    
    func loadAllLessons() async throws -> [Lesson] {
        guard let lessons = try cacheService.load()?.lessons else {
            throw LessonRepositoryError.noDataAvailable
        }
        return lessons
    }
    
    func getLessons() async throws -> [Lesson] {
        let lesson = try await loadAllLessons()
        return lesson.sorted { $0.order < $1.order }
    }
    
    func getLesson(byId id: String) async throws -> Lesson? {
        let lesson = try await loadAllLessons()
        return lesson.first { $0.id == id }
    }
}
