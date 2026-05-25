import XCTest
@testable import RussianSignLanguageDictionary

final class LessonRepositoryTests: XCTestCase {
    private var sut: LessonRepository!
    private var cacheService: CacheService!
    private var cacheDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        cacheDirectoryURL = try createTemporaryDirectory()
        cacheService = CacheService(cacheDirectoryURL: cacheDirectoryURL)
        sut = LessonRepository(cacheService: cacheService)
    }

    override func tearDown() {
        try? cacheService.clearCache()
        sut = nil
        cacheService = nil
        cacheDirectoryURL = nil
        super.tearDown()
    }

    // MARK: - loadAllLessons

    func testLoadAllLessonsThrowsWhenCacheIsEmpty() async {
        do {
            _ = try await sut.loadAllLessons()
            XCTFail("Expected noDataAvailable error")
        } catch let error as LessonRepositoryError {
            XCTAssertEqual(error, .noDataAvailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoadAllLessonsReturnsLessonsFromCache() async throws {
        try seedCache(lessons: [
            makeLesson(id: "lesson-1", order: 1),
            makeLesson(id: "lesson-2", order: 2)
        ])

        let result = try await sut.loadAllLessons()

        XCTAssertEqual(result.map(\.id), ["lesson-1", "lesson-2"])
    }

    // MARK: - getLessons

    func testGetLessonsSortsLessonsByOrderAscending() async throws {
        try seedCache(lessons: [
            makeLesson(id: "lesson-3", order: 3),
            makeLesson(id: "lesson-1", order: 1),
            makeLesson(id: "lesson-2", order: 2)
        ])

        let result = try await sut.getLessons()

        XCTAssertEqual(result.map(\.id), ["lesson-1", "lesson-2", "lesson-3"])
    }

    func testGetLessonsThrowsWhenCacheIsEmpty() async {
        do {
            _ = try await sut.getLessons()
            XCTFail("Expected noDataAvailable error")
        } catch let error as LessonRepositoryError {
            XCTAssertEqual(error, .noDataAvailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - getLesson(byId:)

    func testGetLessonByIdReturnsMatchingLesson() async throws {
        try seedCache(lessons: [
            makeLesson(id: "lesson-1", order: 1),
            makeLesson(id: "lesson-2", order: 2)
        ])

        let result = try await sut.getLesson(byId: "lesson-2")

        XCTAssertEqual(result?.id, "lesson-2")
    }

    func testGetLessonByIdReturnsNilForUnknownId() async throws {
        try seedCache(lessons: [makeLesson(id: "lesson-1", order: 1)])

        let result = try await sut.getLesson(byId: "nonexistent")

        XCTAssertNil(result)
    }

    func testGetLessonByIdThrowsWhenCacheIsEmpty() async {
        do {
            _ = try await sut.getLesson(byId: "lesson-1")
            XCTFail("Expected noDataAvailable error")
        } catch let error as LessonRepositoryError {
            XCTAssertEqual(error, .noDataAvailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Helpers

    private func seedCache(lessons: [Lesson]) throws {
        let data = SyncData(
            categories: [],
            signs: [],
            lessons: lessons,
            lastUpdated: Date()
        )
        try cacheService.save(data)
    }

    private func makeLesson(id: String, order: Int) -> Lesson {
        Lesson(
            id: id,
            title: "Урок \(order)",
            description: "Описание урока \(order)",
            videoUrl: "/lessons/\(id).mp4",
            order: order,
            createdAt: nil,
            updatedAt: nil
        )
    }
}
