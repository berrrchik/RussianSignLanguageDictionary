import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class SignDetailViewModelTests: XCTestCase {
    private var signRepository: SignRepositorySpy!
    private var videoRepository: VideoRepositorySpy!
    private var favoritesRepository: FavoritesRepositorySpy!

    override func setUp() {
        super.setUp()
        signRepository = SignRepositorySpy()
        videoRepository = VideoRepositorySpy()
        favoritesRepository = FavoritesRepositorySpy()
    }

    override func tearDown() {
        signRepository = nil
        videoRepository = nil
        favoritesRepository = nil
        super.tearDown()
    }

    func testInitAddsCurrentSignToVisitedIds() {
        let sut = makeSut(visitedSignIds: ["visited-1"])

        XCTAssertEqual(sut.visitedSignIds, ["visited-1", "sign-1"])
    }

    func testLoadVideoUsesCachedURLWithoutLoadingState() async {
        let cachedURL = URL(fileURLWithPath: "/tmp/cached.mp4")
        videoRepository.cachedVideoURLValue = cachedURL
        favoritesRepository.favoriteLookup["sign-1"] = true
        let sut = makeSut()

        await sut.loadVideo()

        XCTAssertEqual(sut.videoURL, cachedURL)
        XCTAssertFalse(sut.isLoadingVideo)
        XCTAssertNil(sut.videoErrorMessage)
        XCTAssertEqual(videoRepository.videoRequests.count, 0)
        let didPreloadNextVideo = await waitUntil {
            self.videoRepository.preloadVideoRequests.count == 1
        }
        XCTAssertTrue(didPreloadNextVideo)
    }

    func testLoadVideoFetchesDirectURLWhenCacheMisses() async {
        let directURL = URL(fileURLWithPath: "/tmp/direct.mp4")
        videoRepository.cachedVideoURLValue = nil
        videoRepository.directVideoURLResult = .success(directURL)
        favoritesRepository.favoriteLookup["sign-1"] = false
        let sut = makeSut()

        await sut.loadVideo()

        XCTAssertEqual(sut.videoURL, directURL)
        XCTAssertFalse(sut.isLoadingVideo)
        XCTAssertEqual(videoRepository.videoRequests.count, 1)
        XCTAssertEqual(videoRepository.videoRequests.first?.useFavoritesCache, false)
    }

    func testLoadVideoMapsVideoErrorMessage() async {
        videoRepository.cachedVideoURLValue = nil
        videoRepository.directVideoURLResult = .failure(VideoRepositoryError.noInternetConnection)
        favoritesRepository.favoriteLookup["sign-1"] = false
        let sut = makeSut()

        await sut.loadVideo()

        XCTAssertNil(sut.videoURL)
        XCTAssertFalse(sut.isLoadingVideo)
        XCTAssertEqual(
            sut.videoErrorMessage,
            "Нет интернета."
        )
    }

    func testLoadVideoMapsServerFailureToShortStableMessage() async {
        videoRepository.cachedVideoURLValue = nil
        videoRepository.directVideoURLResult = .failure(VideoRepositoryError.videoUnavailable)
        favoritesRepository.favoriteLookup["sign-1"] = false
        let sut = makeSut()

        await sut.loadVideo()

        XCTAssertEqual(sut.videoErrorMessage, "Видео сейчас недоступно.")
        XCTAssertFalse(sut.isLoadingVideo)
    }

    func testToggleFavoriteAddsFavoriteWhenCurrentlyNotFavorite() {
        favoritesRepository.favoriteLookup["sign-1"] = false
        let sut = makeSut()

        sut.toggleFavorite()

        XCTAssertTrue(sut.isFavorite)
        XCTAssertEqual(favoritesRepository.addFavoriteCalls, ["sign-1"])
        XCTAssertEqual(favoritesRepository.removeFavoriteCalls, [])
    }

    func testToggleFavoriteRemovesFavoriteWhenCurrentlyFavorite() {
        favoritesRepository.favoriteLookup["sign-1"] = true
        let sut = makeSut()

        sut.toggleFavorite()

        XCTAssertFalse(sut.isFavorite)
        XCTAssertEqual(favoritesRepository.removeFavoriteCalls, ["sign-1"])
        XCTAssertEqual(favoritesRepository.addFavoriteCalls, [])
    }

    func testLoadCategoryNameUsesRepositoryCategories() async {
        signRepository.loadCategoriesResult = .success([
            AppCategory(
                id: "category-1",
                name: "Категория 1",
                order: 1,
                signCount: 1,
                icon: nil,
                color: nil,
                createdAt: nil,
                updatedAt: nil
            )
        ])
        let sut = makeSut()

        await sut.loadCategoryName()

        XCTAssertEqual(sut.categoryName, "Категория 1")
    }

    func testVideoNavigationUpdatesIndexAndAvailabilityFlags() {
        let sut = makeSut(sign: makeSignWithMultipleVideos())

        XCTAssertFalse(sut.canGoBack)
        XCTAssertTrue(sut.canGoNext)

        sut.showNextVideo()
        XCTAssertEqual(sut.currentVideoIndex, 1)
        XCTAssertTrue(sut.canGoBack)
        XCTAssertFalse(sut.canGoNext)

        sut.showPreviousVideo()
        XCTAssertEqual(sut.currentVideoIndex, 0)
    }

    func testCleanupVideoClearsCurrentVideoURL() async {
        let sut = makeSut()
        videoRepository.cachedVideoURLValue = URL(fileURLWithPath: "/tmp/cached.mp4")

        await sut.loadVideo()
        XCTAssertNotNil(sut.videoURL)

        sut.cleanupVideo()
        XCTAssertNil(sut.videoURL)
    }

    func testNavigateToSignLoadsSynonymAndStopsLoading() async {
        let synonym = makeSign(id: "synonym-1", word: "Синоним")
        signRepository.getSignResult = .success(synonym)
        let sut = makeSut()

        sut.navigateToSign("synonym-1")

        let didNavigate = await waitUntil {
            sut.selectedSynonymSign?.id == "synonym-1"
        }
        XCTAssertTrue(didNavigate)
        XCTAssertEqual(signRepository.getSignCallArguments, ["synonym-1"])
        XCTAssertFalse(sut.isLoadingSynonym)
        XCTAssertNil(sut.synonymError)
    }

    func testNavigateToSignShowsNotFoundErrorWhenRepositoryReturnsNil() async {
        signRepository.getSignResult = .success(nil)
        let sut = makeSut()

        sut.navigateToSign("missing")

        let didShowNotFoundError = await waitUntil {
            sut.synonymError == "Жест не найден"
        }
        XCTAssertTrue(didShowNotFoundError)
        XCTAssertFalse(sut.isLoadingSynonym)
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
        let sut = makeSut()

        sut.navigateToSign("synonym-2")
        let didShowRetryableError = await waitUntil {
            sut.synonymError?.contains("Не удалось загрузить жест") == true
        }
        XCTAssertTrue(didShowRetryableError)

        sut.retrySynonymLoad()

        let didLoadAfterRetry = await waitUntil {
            sut.selectedSynonymSign?.id == "synonym-2"
        }
        XCTAssertTrue(didLoadAfterRetry)
        XCTAssertEqual(signRepository.getSignCallArguments, ["synonym-2", "synonym-2"])
    }

    private func makeSut(
        sign: Sign? = nil,
        visitedSignIds: Set<String> = []
    ) -> SignDetailViewModel {
        SignDetailViewModel(
            sign: sign ?? makeDefaultSign(),
            signRepository: signRepository,
            videoRepository: videoRepository,
            favoritesRepository: favoritesRepository,
            visitedSignIds: visitedSignIds
        )
    }

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

    private func makeSignWithMultipleVideos() -> Sign {
        Sign(
            id: "sign-1",
            word: "Привет",
            description: "Тест",
            categoryId: "category-1",
            videos: [
                SignVideo(id: 1, url: "https://example.com/1.mp4", contextDescription: "Первое", order: 1, createdAt: nil, updatedAt: nil),
                SignVideo(id: 2, url: "https://example.com/2.mp4", contextDescription: "Второе", order: 2, createdAt: nil, updatedAt: nil)
            ],
            synonyms: [
                SignSynonym(id: "sign-1", word: "Привет"),
                SignSynonym(id: "synonym-2", word: "Здравствуйте")
            ]
        )
    }

    private func makeDefaultSign() -> Sign {
        Sign(
            id: "sign-1",
            word: "Привет",
            description: "Тестовый жест",
            categoryId: "category-1",
            videos: [
                SignVideo(id: 1, url: "https://example.com/1.mp4", contextDescription: "Первое", order: 1, createdAt: nil, updatedAt: nil),
                SignVideo(id: 2, url: "https://example.com/2.mp4", contextDescription: "Второе", order: 2, createdAt: nil, updatedAt: nil)
            ],
            synonyms: [
                SignSynonym(id: "sign-1", word: "Привет"),
                SignSynonym(id: "synonym-2", word: "Здравствуйте")
            ]
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
