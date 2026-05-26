import Foundation
import os.log

@MainActor
final class LessonDetailViewModel: ObservableObject {
    // MARK: - Properties
    
    let lesson: Lesson
    
    @Published private(set) var videoURL: URL?
    @Published private(set) var isLoadingVideo: Bool = false
    @Published private(set) var videoErrorMessage: String?
    
    private let videoRepository: VideoRepositoryProtocol
    private let logger = Logger(subsystem: "com.rsl.LessonDetailViewModel", category: "viewmodel")
    
    // MARK: - Initialization

    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init(lesson: Lesson) {
        let container = DIContainer.shared
        self.init(
            lesson: lesson,
            videoRepository: container.resolve(VideoRepositoryProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(lesson: Lesson, videoRepository: VideoRepositoryProtocol) {
        self.lesson = lesson
        self.videoRepository = videoRepository
    }
    
    // MARK: - Public Methods
    
    func loadVideo() async {
        isLoadingVideo = true
        videoErrorMessage = nil
        videoURL = nil
        
        do {
            let url = try await videoRepository.getVideoURL(for: lesson)
            videoURL = url
            logger.info("✅ Видео урока \(self.lesson.id) загружено")
        } catch {
            videoErrorMessage = ErrorMessageMapper.message(for: error)
            logger.error("❌ Ошибка загрузки видео урока \(self.lesson.id): \(error.localizedDescription)")
        }
        
        isLoadingVideo = false
    }
}
