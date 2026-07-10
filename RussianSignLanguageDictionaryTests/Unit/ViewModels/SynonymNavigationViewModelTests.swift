import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class SynonymNavigationViewModelTests: XCTestCase {
    private var signRepository: SignRepositorySpy!
    private var sut: SynonymNavigationViewModel!

    override func setUp() {
        super.setUp()
        signRepository = SignRepositorySpy()
        sut = SynonymNavigationViewModel(signRepository: signRepository)
    }

    override func tearDown() {
        sut = nil
        signRepository = nil
        super.tearDown()
    }

    func testNavigateToSignLoadsSynonymAndStopsLoading() async {
        let synonym = makeSign(id: "synonym-1", word: "Синоним")
        signRepository.getSignResult = .success(synonym)

        sut.navigateToSign("synonym-1")

        let didNavigate = await waitUntil {
            self.sut.selectedSign?.id == "synonym-1"
        }
        XCTAssertTrue(didNavigate)
        XCTAssertEqual(signRepository.getSignCallArguments, ["synonym-1"])
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testNavigateToSignShowsNotFoundErrorWhenRepositoryReturnsNil() async {
        signRepository.getSignResult = .success(nil)

        sut.navigateToSign("missing")

        let didShowNotFoundError = await waitUntil {
            self.sut.errorMessage == "Жест не найден"
        }
        XCTAssertTrue(didShowNotFoundError)
        XCTAssertFalse(sut.isLoading)
    }

    func testNavigateToSignShowsErrorAndRetryRepeatsLastRequest() async {
        var attempts = 0
        signRepository.getSignImplementation = { _ in
            attempts += 1
            if attempts == 1 {
                throw SignRepositoryError.fileNotFound
            }
            return self.makeSign(id: "synonym-2", word: "Повтор")
        }

        sut.navigateToSign("synonym-2")
        let didShowRetryableError = await waitUntil {
            self.sut.errorMessage == "Не удалось загрузить данные"
        }
        XCTAssertTrue(didShowRetryableError)

        sut.retry()

        let didLoadAfterRetry = await waitUntil {
            self.sut.selectedSign?.id == "synonym-2"
        }
        XCTAssertTrue(didLoadAfterRetry)
        XCTAssertEqual(signRepository.getSignCallArguments, ["synonym-2", "synonym-2"])
    }

    func testStaleResponseDoesNotOverwriteNewerSelection() async {
        let slowSign = makeSign(id: "slow", word: "Медленный")
        let fastSign = makeSign(id: "fast", word: "Быстрый")
        let slowReleased = ManagedContinuation()

        signRepository.getSignImplementation = { id in
            if id == "slow" {
                await slowReleased.wait()
                return slowSign
            }
            return fastSign
        }

        sut.navigateToSign("slow")
        let slowRequestStarted = await waitUntil {
            self.signRepository.getSignCallArguments.contains("slow")
        }
        XCTAssertTrue(slowRequestStarted)

        // Пользователь успевает выбрать другой синоним, пока первый запрос ещё летит.
        sut.navigateToSign("fast")
        let fastLoaded = await waitUntil {
            self.sut.selectedSign?.id == "fast"
        }
        XCTAssertTrue(fastLoaded)

        // Отпускаем устаревший запрос — его результат не должен перезаписать выбор.
        await slowReleased.resume()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(sut.selectedSign?.id, "fast")
    }

    // MARK: - Helpers

    private func makeSign(id: String, word: String) -> Sign {
        Sign(
            id: id,
            word: word,
            description: "Описание \(word)",
            categoryId: "category-1",
            videos: [TestFixtures.video],
            synonyms: nil
        )
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

/// Небольшой помощник для контролируемой приостановки async-задачи в тестах.
private actor ManagedContinuation {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}
