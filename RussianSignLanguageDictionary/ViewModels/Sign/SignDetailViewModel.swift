import Foundation
import Combine
import os.log

@MainActor
final class SignDetailViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentVideoIndex: Int = 0
    @Published private(set) var videoURL: URL?
    @Published private(set) var isLoadingVideo: Bool = false
    @Published private(set) var videoErrorMessage: String?
    @Published private(set) var categoryName: String

    // MARK: - Sub-ViewModels

    let favoriteViewModel: SignFavoriteViewModel
    let synonymViewModel: SynonymNavigationViewModel

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.rsl.signDetail", category: "SignDetailViewModel")
    private var cancellables = Set<AnyCancellable>()

    let sign: Sign
    let visitedSignIds: Set<String>

    // MARK: - Computed Properties

    var currentVideo: SignVideo? {
        guard let videos = sign.videos,
              currentVideoIndex >= 0,
              currentVideoIndex < videos.count else {
            return nil
        }
        return videos[currentVideoIndex]
    }

    var currentContextDescription: String? {
        currentVideo?.contextDescription
    }

    var canGoNext: Bool {
        guard let videos = sign.videos else { return false }
        return currentVideoIndex < videos.count - 1
    }

    var canGoBack: Bool {
        return currentVideoIndex > 0
    }

    private var nextVideo: SignVideo? {
        guard let videos = sign.videos,
              currentVideoIndex >= 0,
              currentVideoIndex < videos.count - 1 else {
            return nil
        }
        return videos[currentVideoIndex + 1]
    }

    // MARK: - Dependencies

    private let signRepository: SignRepositoryProtocol
    private let videoRepository: VideoRepositoryProtocol
    private let favoritesRepository: FavoritesRepositoryProtocol

    // MARK: - Init

    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init(sign: Sign, visitedSignIds: Set<String> = []) {
        let container = DIContainer.shared
        self.init(
            sign: sign,
            signRepository: container.resolve(SignRepositoryProtocol.self),
            videoRepository: container.resolve(VideoRepositoryProtocol.self),
            favoritesRepository: container.resolve(FavoritesRepositoryProtocol.self),
            offlinePreparationService: container.resolve(OfflinePreparationServiceProtocol.self),
            visitedSignIds: visitedSignIds
        )
    }

    /// Полный init для тестов и preview (constructor injection)
    init(
        sign: Sign,
        signRepository: SignRepositoryProtocol,
        videoRepository: VideoRepositoryProtocol,
        favoritesRepository: FavoritesRepositoryProtocol,
        offlinePreparationService: OfflinePreparationServiceProtocol,
        visitedSignIds: Set<String> = []
    ) {
        self.sign = sign
        self.signRepository = signRepository
        self.videoRepository = videoRepository
        self.favoritesRepository = favoritesRepository
        self.visitedSignIds = visitedSignIds.union([sign.id])
        self.categoryName = CategoryDisplayDataHelper.name(for: sign.categoryId, in: [:])
        self.favoriteViewModel = SignFavoriteViewModel(
            sign: sign,
            favoritesRepository: favoritesRepository,
            offlinePreparationService: offlinePreparationService
        )
        self.synonymViewModel = SynonymNavigationViewModel(signRepository: signRepository)

        signRepository.dataUpdatedPublisher
            .sink { [weak self] updatedData in
                Task { @MainActor [weak self] in
                    self?.applyCategoryName(from: updatedData.categories)
                }
            }
            .store(in: &cancellables)

        // Логируем просмотр жеста при создании ViewModel (пользователь открыл жест)
        // НЕ в loadVideo(), т.к. видео может не загрузиться, но просмотр жеста уже произошёл
        AnalyticsService.logSignViewed(signId: sign.id, word: sign.word, categoryId: sign.categoryId)
    }

    // MARK: - Public Methods

    func loadVideo() async {
        guard let video = currentVideo else { return }

        let trace = PerformanceService.startTrace("screen_sign_detail_load")
        PerformanceService.addAttribute(trace, name: "sign_id", value: sign.id)
        PerformanceService.addAttribute(trace, name: "video_id", value: String(video.id))
        defer { PerformanceService.stopTrace(trace) }

        videoErrorMessage = nil

        if let cachedURL = videoRepository.cachedVideoURL(for: video) {
            videoURL = cachedURL
            isLoadingVideo = false
            logger.debug("⚡ Видео \(video.id) загружено из кеша (без loading)")
            PerformanceService.addAttribute(trace, name: "source", value: "cache")

            if favoritesRepository.isFavorite(signId: sign.id) {
                preloadNextVideo()
            }
            return
        }

        isLoadingVideo = true
        let useFavoritesCache = favoritesRepository.isFavorite(signId: sign.id)
        PerformanceService.addAttribute(trace, name: "source", value: useFavoritesCache ? "favorites_cache" : "network")
        PerformanceService.addAttribute(trace, name: "is_favorite", value: useFavoritesCache ? "true" : "false")

        do {
            let url = try await videoRepository.getVideoURL(
                for: video,
                useFavoritesCache: useFavoritesCache
            )

            // Пользователь мог переключить видео, пока запрос был в полёте —
            // устаревший результат не должен перезаписать текущее видео.
            guard currentVideo?.id == video.id else { return }

            videoURL = url
            isLoadingVideo = false

            if useFavoritesCache {
                preloadNextVideo()
            }

        } catch {
            guard currentVideo?.id == video.id else { return }

            videoErrorMessage = ErrorMessageMapper.message(for: error)
            isLoadingVideo = false
            logger.error("❌ Ошибка загрузки видео: \(error.localizedDescription)")
            PerformanceService.addAttribute(trace, name: "error", value: error.localizedDescription)
            CrashlyticsErrorReporter.capture(
                error,
                context: [
                    "signId": sign.id,
                    "videoId": currentVideo?.id ?? ""
                ],
                subsystem: "com.rsl.signDetail"
            )
        }
    }

    func showNextVideo() {
        guard canGoNext else { return }
        currentVideoIndex += 1
    }

    func showPreviousVideo() {
        guard canGoBack else { return }
        currentVideoIndex -= 1
    }

    func loadCategoryName() async {
        do {
            let categories = try await signRepository.loadCategories()
            applyCategoryName(from: categories)
            favoriteViewModel.updateSnapshotIfFavorite(categoryName: categoryName)
        } catch {
            logger.warning("⚠️ Не удалось загрузить название категории: \(error.localizedDescription)")
        }
    }

    func cleanupVideo() {
        videoURL = nil
        logger.debug("🗑️ Видео ресурсы очищены для жеста \(self.sign.id)")
    }

    // MARK: - Private Methods

    private func applyCategoryName(from categories: [Category]) {
        let categoryNamesById = CategoryDisplayDataHelper.categoryNamesById(
            from: CategoryDisplayDataHelper.sortedCategories(categories)
        )
        categoryName = CategoryDisplayDataHelper.name(for: sign.categoryId, in: categoryNamesById)
    }

    private func preloadNextVideo() {
        guard let nextVideo = nextVideo else { return }

        Task.detached { [weak self] in
            guard let self = self else { return }

            do {
                try await self.videoRepository.preloadVideo(
                    video: nextVideo,
                    useFavoritesCache: true
                )
                await MainActor.run {
                    self.logger.debug("✅ Предзагружено следующее видео \(nextVideo.id)")
                }
            } catch {
                await MainActor.run {
                    self.logger.warning("⚠️ Не удалось предзагрузить следующее видео: \(error.localizedDescription)")
                }
            }
        }
    }
}
