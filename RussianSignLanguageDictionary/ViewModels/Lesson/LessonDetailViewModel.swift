import Foundation
import os.log

@MainActor
final class LessonDetailViewModel: ObservableObject {
    // MARK: - Properties
    
    let lesson: Lesson
    let allLessons: [Lesson]
    
    @Published private(set) var videoURL: URL?
    @Published private(set) var isLoadingVideo: Bool = false
    @Published private(set) var videoErrorMessage: String?
    
    private let videoRepository: VideoRepositoryProtocol
    private let logger = Logger(subsystem: "com.rsl.LessonDetailViewModel", category: "viewmodel")
    
    // MARK: - Computed Properties
    
    var currentIndex: Int {
        allLessons.firstIndex(where: { $0.id == lesson.id }) ?? 0
    }
    
    var canGoBack: Bool {
        currentIndex > 0
    }
    
    var canGoNext: Bool {
        currentIndex < allLessons.count - 1
    }
    
    // MARK: - Initialization

    init(lesson: Lesson, allLessons: [Lesson], videoRepository: VideoRepositoryProtocol) {
        self.lesson = lesson
        self.allLessons = allLessons
        self.videoRepository = videoRepository
    }
    
    // MARK: - Public Methods
    
    func loadVideo() async {
        isLoadingVideo = true
        videoErrorMessage = nil
        
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
    
    func showPreviousLesson() -> Lesson? {
        guard canGoBack else { return nil }
        return allLessons[currentIndex - 1]
    }
    
    func showNextLesson() -> Lesson? {
        guard canGoNext else { return nil }
        return allLessons[currentIndex + 1]
    }
}
