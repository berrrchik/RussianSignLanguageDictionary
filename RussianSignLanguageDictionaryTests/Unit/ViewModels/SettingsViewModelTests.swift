import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var videoRepository: VideoRepositorySpy!
    private var favoritesRepository: FavoritesRepositorySpy!
    private var sut: SettingsViewModel!

    override func setUp() {
        super.setUp()
        videoRepository = VideoRepositorySpy()
        favoritesRepository = FavoritesRepositorySpy()
        sut = SettingsViewModel(
            videoRepository: videoRepository,
            favoritesRepository: favoritesRepository
        )
    }

    override func tearDown() {
        sut = nil
        videoRepository = nil
        favoritesRepository = nil
        super.tearDown()
    }

    func testClearCacheCallsVideoRepositoryClearCache() {
        sut.clearCache()

        XCTAssertEqual(videoRepository.clearCacheCallCount, 1)
    }

    func testClearCacheReconcilesFavoriteOfflineState() async {
        sut.clearCache()

        let didReconcile = await waitUntil {
            self.favoritesRepository.reconcileOfflineStateCallCount == 1
        }

        XCTAssertTrue(didReconcile)
    }

    func testClearCacheShowsSuccessMessage() {
        sut.clearCache()

        XCTAssertEqual(sut.cacheClearedMessage, "Кэш успешно очищен")
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollInterval: UInt64 = 20_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return true
            }

            try? await Task.sleep(nanoseconds: pollInterval)
        }

        return condition()
    }
}
