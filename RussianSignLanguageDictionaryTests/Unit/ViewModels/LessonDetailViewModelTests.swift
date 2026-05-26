import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class LessonDetailViewModelTests: XCTestCase {
    private var videoRepository: VideoRepositorySpy!

    override func setUp() {
        super.setUp()
        videoRepository = VideoRepositorySpy()
    }

    override func tearDown() {
        videoRepository = nil
        super.tearDown()
    }

    func testLoadVideoMapsVideoUnavailableMessage() async {
        videoRepository.lessonVideoURLResult = .failure(VideoRepositoryError.videoUnavailable)
        let sut = makeSut()

        await sut.loadVideo()

        XCTAssertNil(sut.videoURL)
        XCTAssertFalse(sut.isLoadingVideo)
        XCTAssertEqual(sut.videoErrorMessage, "Видео сейчас недоступно.")
    }

    func testLoadVideoRequestsRepositoryAgainOnRepeatedLoad() async {
        let preparedURL = URL(fileURLWithPath: "/tmp/lesson.mp4")
        videoRepository.lessonVideoURLResult = .success(preparedURL)
        let sut = makeSut()

        await sut.loadVideo()
        await sut.loadVideo()

        XCTAssertEqual(sut.videoURL, preparedURL)
        XCTAssertEqual(videoRepository.lessonRequests.count, 2)
        XCTAssertFalse(sut.isLoadingVideo)
    }

    private func makeSut() -> LessonDetailViewModel {
        LessonDetailViewModel(
            lesson: Lesson(
                id: "lesson-1",
                title: "Lesson",
                description: "Description",
                videoUrl: "/lessons/lesson.mp4",
                order: 1,
                createdAt: nil,
                updatedAt: nil
            ),
            videoRepository: videoRepository
        )
    }
}
