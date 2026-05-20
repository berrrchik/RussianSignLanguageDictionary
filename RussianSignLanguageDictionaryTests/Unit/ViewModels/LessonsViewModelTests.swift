import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class LessonsViewModelTests: XCTestCase {
    private var lessonRepository: LessonRepositorySpy!
    private var sut: LessonsViewModel!

    override func setUp() {
        super.setUp()
        lessonRepository = LessonRepositorySpy()
        sut = LessonsViewModel(lessonRepository: lessonRepository)
    }

    override func tearDown() {
        sut = nil
        lessonRepository = nil
        super.tearDown()
    }

    func testInitialStateIsIdle() {
        XCTAssertEqual(sut.lessons, [])
        XCTAssertEqual(sut.state, .idle)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadLessonsPublishesLoadingStateBeforeLoaded() async {
        let started = expectation(description: "getLessons started")
        var continuation: CheckedContinuation<[Lesson], Never>?

        lessonRepository.getLessonsImplementation = {
            started.fulfill()
            return await withCheckedContinuation { checkedContinuation in
                continuation = checkedContinuation
            }
        }

        let task = Task { await self.sut.loadLessons() }

        await fulfillment(of: [started], timeout: 1.0)
        XCTAssertEqual(sut.state, .loading)

        continuation?.resume(returning: [makeLesson(id: "lesson-1", title: "Первый урок", order: 1)])
        await task.value

        XCTAssertEqual(sut.state, .loaded)
    }

    func testLoadLessonsStoresRepositoryLessons() async {
        let lessons = [
            makeLesson(id: "lesson-1", title: "Первый урок", order: 1),
            makeLesson(id: "lesson-2", title: "Второй урок", order: 2)
        ]
        lessonRepository.getLessonsResult = .success(lessons)

        await sut.loadLessons()

        XCTAssertEqual(lessonRepository.getLessonsCallCount, 1)
        XCTAssertEqual(sut.lessons.map(\.id), ["lesson-1", "lesson-2"])
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadLessonsMapsRepositoryError() async {
        lessonRepository.getLessonsResult = .failure(LessonRepositoryError.noDataAvailable)

        await sut.loadLessons()

        XCTAssertEqual(sut.lessons, [])
        XCTAssertEqual(
            sut.state,
            .error("Данные уроков недоступны. Попробуйте сначала выполнить синхронизацию.")
        )
        XCTAssertEqual(
            sut.errorMessage,
            "Данные уроков недоступны. Попробуйте сначала выполнить синхронизацию."
        )
    }

    private func makeLesson(id: String, title: String, order: Int) -> Lesson {
        Lesson(
            id: id,
            title: title,
            description: "Описание \(title)",
            videoUrl: "https://example.com/\(id).mp4",
            order: order,
            createdAt: nil,
            updatedAt: nil
        )
    }
}
