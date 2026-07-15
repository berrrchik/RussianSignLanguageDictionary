import Foundation

/// Mock репозиторий уроков для тестирования и Preview
@MainActor
final class MockLessonRepository: LessonRepositoryProtocol {
    
    // MARK: - Configuration
    
    /// Уроки для возврата
    var lessons: [Lesson] = Lesson.mockLessons()
    
    /// Симуляция ошибки
    var shouldThrowError: Bool = false
    
    /// Ошибка для симуляции
    var errorToThrow: Error = LessonRepositoryError.noDataAvailable
    
    /// Задержка загрузки (в наносекундах)
    var loadDelay: UInt64 = 0
    
    // MARK: - LessonRepositoryProtocol
    
    func loadAllLessons() async throws -> [Lesson] {
        if loadDelay > 0 {
            try? await Task.sleep(nanoseconds: loadDelay)
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return lessons
    }
    
    func getLesson(byId id: String) async throws -> Lesson? {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return lessons.first { $0.id == id }
    }
    
    func getLessons() async throws -> [Lesson] {
        let allLessons = try await loadAllLessons()
        return allLessons.sorted { $0.order < $1.order }
    }
}
