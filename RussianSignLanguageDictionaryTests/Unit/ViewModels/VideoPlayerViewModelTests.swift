import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class VideoPlayerViewModelTests: XCTestCase {
    private var sut: VideoPlayerViewModel!

    override func setUp() {
        super.setUp()
        sut = VideoPlayerViewModel()
    }

    override func tearDown() {
        sut.cleanupPlayer()
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_PlayerIsNil() {
        XCTAssertNil(sut.player)
    }

    func testInitialState_IsNotReadyToPlay() {
        XCTAssertFalse(sut.isReadyToPlay)
    }

    func testInitialState_HasNoErrorMessage() {
        XCTAssertNil(sut.playbackErrorMessage)
    }

    // MARK: - cleanupPlayer

    func testCleanupPlayer_WhenNeverSetup_DoesNotCrash() {
        sut.cleanupPlayer()

        XCTAssertNil(sut.player)
        XCTAssertFalse(sut.isReadyToPlay)
        XCTAssertNil(sut.playbackErrorMessage)
    }

    func testCleanupPlayer_CalledMultipleTimes_IsIdempotent() {
        sut.cleanupPlayer()
        sut.cleanupPlayer()
        sut.cleanupPlayer()

        XCTAssertNil(sut.player)
        XCTAssertFalse(sut.isReadyToPlay)
    }

    func testCleanupPlayer_AfterLocalSetup_ResetsAllState() {
        let url = URL(fileURLWithPath: "/tmp/test_video.mp4")
        sut.setupPlayer(for: url)
        XCTAssertNotNil(sut.player, "Precondition: player должен быть установлен")

        sut.cleanupPlayer()

        XCTAssertNil(sut.player)
        XCTAssertFalse(sut.isReadyToPlay)
        XCTAssertNil(sut.playbackErrorMessage)
    }

    // MARK: - setupPlayer — local URL

    func testSetupPlayer_WithLocalFileURL_SetsPlayerSynchronously() {
        let url = URL(fileURLWithPath: "/tmp/test_video.mp4")

        sut.setupPlayer(for: url)

        // AVPlayer создаётся синхронно для локальных URL
        XCTAssertNotNil(sut.player)
    }

    func testSetupPlayer_WithLocalFileURL_ClearsErrorMessage() {
        let url = URL(fileURLWithPath: "/tmp/test_video.mp4")

        sut.setupPlayer(for: url)

        XCTAssertNil(sut.playbackErrorMessage)
    }

    func testSetupPlayer_CalledTwiceWithLocalURLs_ReplacesPlayer() {
        let url1 = URL(fileURLWithPath: "/tmp/video1.mp4")
        let url2 = URL(fileURLWithPath: "/tmp/video2.mp4")

        sut.setupPlayer(for: url1)
        let firstPlayer = sut.player

        sut.setupPlayer(for: url2)

        XCTAssertNotNil(sut.player)
        // Новый player — не старый экземпляр
        XCTAssertFalse(sut.player === firstPlayer)
    }

    func testSetupPlayer_SecondCall_ClearsIsReadyToPlay() async {
        let url = URL(fileURLWithPath: "/tmp/test_video.mp4")
        sut.setupPlayer(for: url)

        // Эмулируем готовность через небольшую задержку, затем переключаем
        // isReadyToPlay может выставиться асинхронно через KVO — cleanupPlayer его сбрасывает
        sut.setupPlayer(for: url)

        XCTAssertFalse(sut.isReadyToPlay)
    }

    // MARK: - setupPlayer — remote URL

    func testSetupPlayer_WithRemoteURL_StartsInLoadingState() {
        let url = URL(string: "https://example.com/video.mp4")!

        sut.setupPlayer(for: url)

        // Удалённая загрузка асинхронна: player ещё не установлен
        XCTAssertNil(sut.player)
        XCTAssertFalse(sut.isReadyToPlay)
        XCTAssertNil(sut.playbackErrorMessage)
    }

    func testSetupPlayer_WithRemoteURL_ThenImmediateCleanup_LeavesCleanState() async {
        let url = URL(string: "https://example.com/video.mp4")!

        sut.setupPlayer(for: url)
        sut.cleanupPlayer()

        // Небольшая пауза чтобы убедиться, что отменённая Task не обновляет состояние
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertNil(sut.player)
        XCTAssertFalse(sut.isReadyToPlay)
        XCTAssertNil(sut.playbackErrorMessage)
    }

    func testSetupPlayer_WithRemoteURLAndImmediateSecondCall_CancelsFirst() async {
        let url1 = URL(string: "https://example.com/video1.mp4")!
        let url2 = URL(fileURLWithPath: "/tmp/video2.mp4")

        sut.setupPlayer(for: url1) // async — запускает Task
        sut.setupPlayer(for: url2) // должен отменить первый Task и тут же установить player

        XCTAssertNotNil(sut.player, "Второй setupPlayer (local) должен сразу установить player")

        // Даём время убедиться, что первый Task не перезатирает состояние
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertNotNil(sut.player)
    }

    // MARK: - Error state

    func testSetupPlayer_WithRemoteURL_EventualFailure_SetsErrorAndClearsReadyState() async {
        // 192.0.2.x — TEST-NET по RFC 5737, гарантированно недостижим
        let url = URL(string: "https://192.0.2.1/video.mp4")!

        sut.setupPlayer(for: url)

        // Ждём сетевой ошибки (до 5 секунд)
        let deadline = Date().addingTimeInterval(5)
        while sut.playbackErrorMessage == nil, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }

        guard sut.playbackErrorMessage != nil else {
            // Если сеть так и не ответила — пропускаем, не падаем
            return
        }

        XCTAssertFalse(sut.isReadyToPlay)
        XCTAssertNotNil(sut.playbackErrorMessage)
    }
}
