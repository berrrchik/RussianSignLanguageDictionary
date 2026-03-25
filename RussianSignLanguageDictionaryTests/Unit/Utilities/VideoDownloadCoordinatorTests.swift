import XCTest
@testable import RussianSignLanguageDictionary

final class VideoDownloadCoordinatorTests: XCTestCase {
    func testGetOrCreateTaskReturnsSameTaskForSameVideoId() async throws {
        let coordinator = VideoDownloadCoordinator()
        let counter = InvocationCounter()

        async let first: URL = coordinator.getOrCreateTask(videoId: 1) {
            await counter.increment()
            try await Task.sleep(nanoseconds: 100_000_000)
            return URL(fileURLWithPath: "/tmp/video-1.mp4")
        }.task.value

        async let second: URL = coordinator.getOrCreateTask(videoId: 1) {
            await counter.increment()
            return URL(fileURLWithPath: "/tmp/video-1-second.mp4")
        }.task.value

        let results = try await [first, second]
        let invocationCount = await counter.value

        XCTAssertEqual(results[0], results[1])
        XCTAssertEqual(invocationCount, 1)
    }

    func testGetOrCreateTaskCreatesIndependentTasksForDifferentVideoIds() async throws {
        let coordinator = VideoDownloadCoordinator()
        let counter = InvocationCounter()

        async let first: URL = coordinator.getOrCreateTask(videoId: 1) {
            await counter.increment()
            return URL(fileURLWithPath: "/tmp/video-1.mp4")
        }.task.value

        async let second: URL = coordinator.getOrCreateTask(videoId: 2) {
            await counter.increment()
            return URL(fileURLWithPath: "/tmp/video-2.mp4")
        }.task.value

        let results = try await [first, second]
        let invocationCount = await counter.value

        XCTAssertNotEqual(results[0], results[1])
        XCTAssertEqual(invocationCount, 2)
    }

    func testGetOrCreateTaskRemovesCompletedTask() async throws {
        let coordinator = VideoDownloadCoordinator()
        let counter = InvocationCounter()

        let first = await coordinator.getOrCreateTask(videoId: 7) {
            await counter.increment()
            return URL(fileURLWithPath: "/tmp/video-7.mp4")
        }
        _ = try await first.task.value

        let second = await coordinator.getOrCreateTask(videoId: 7) {
            await counter.increment()
            return URL(fileURLWithPath: "/tmp/video-7-again.mp4")
        }
        _ = try await second.task.value
        let invocationCount = await counter.value

        XCTAssertFalse(second.isExisting)
        XCTAssertEqual(invocationCount, 2)
    }

    func testGetOrCreateTaskRemovesFailedTask() async {
        let coordinator = VideoDownloadCoordinator()
        let counter = InvocationCounter()

        let first = await coordinator.getOrCreateTask(videoId: 9) {
            await counter.increment()
            throw TestError.expected
        }

        do {
            _ = try await first.task.value
            XCTFail("Expected failure")
        } catch {}

        try? await Task.sleep(nanoseconds: 50_000_000)

        let second = await coordinator.getOrCreateTask(videoId: 9) {
            await counter.increment()
            return URL(fileURLWithPath: "/tmp/video-9.mp4")
        }
        _ = try? await second.task.value
        let invocationCount = await counter.value

        XCTAssertFalse(second.isExisting)
        XCTAssertEqual(invocationCount, 2)
    }
}

private actor InvocationCounter {
    private var count = 0

    func increment() {
        count += 1
    }

    var value: Int { count }
}

private enum TestError: Error {
    case expected
}
