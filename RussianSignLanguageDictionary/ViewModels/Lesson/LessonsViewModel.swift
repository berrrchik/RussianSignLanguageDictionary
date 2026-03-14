import Foundation
import os.log


@MainActor
final class LessonsViewModel: ObservableObject {
    @Published private(set) var lessons: [Lesson] = []
    @Published private(set) var state: LoadingState = .idle
    @Published private(set) var errorMessage: String?
    
    private let logger = Logger(subsystem: "com.rsl.LessonsViewModel", category: "viewmodel")
    
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }
    
    private let lessonRepository: LessonRepositoryProtocol
    
    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            lessonRepository: container.resolve(LessonRepositoryProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(lessonRepository: LessonRepositoryProtocol) {
        self.lessonRepository = lessonRepository
    }
    
    func loadLessons() async {
        state = .loading
        errorMessage = nil
        
        do {
            let loadedLessons = try await lessonRepository.getLessons()
            lessons = loadedLessons
            state = .loaded
            logger.info("✅ Загружено \(loadedLessons.count) уроков")
        } catch {
            let message = ErrorMessageMapper.message(for: error)
            state = .error(message)
            errorMessage = message
            logger.error("❌ Ошибка загрузки уроков: \(error.localizedDescription)")
        }
    }
}
