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
    @Published var isFavorite: Bool = false
    @Published private(set) var favoriteOfflineStatus: FavoriteOfflineStatus?
    @Published private(set) var categoryName: String
    
    // MARK: - Synonym Navigation Properties
    
    @Published var selectedSynonymSign: Sign?
    @Published private(set) var isLoadingSynonym: Bool = false
    @Published private(set) var synonymError: String?
    private var lastRequestedSynonymId: String?
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.signDetail", category: "SignDetailViewModel")
    private var cancellables = Set<AnyCancellable>()
    private var favoritePreparationTask: Task<Void, Never>?
    
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
    
    let signRepository: SignRepositoryProtocol
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
            visitedSignIds: visitedSignIds
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(
        sign: Sign,
        signRepository: SignRepositoryProtocol,
        videoRepository: VideoRepositoryProtocol,
        favoritesRepository: FavoritesRepositoryProtocol,
        visitedSignIds: Set<String> = []
    ) {
        self.sign = sign
        self.signRepository = signRepository
        self.videoRepository = videoRepository
        self.favoritesRepository = favoritesRepository
        self.visitedSignIds = visitedSignIds.union([sign.id])
        self.isFavorite = favoritesRepository.isFavorite(signId: sign.id)
        self.favoriteOfflineStatus = favoritesRepository.getFavoriteEntry(signId: sign.id)?.offlineStatus
        self.categoryName = CategoryDisplayDataHelper.name(for: sign.categoryId, in: [:])

        signRepository.dataUpdatedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedData in
                self?.applyCategoryName(from: updatedData.categories)
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
            videoURL = url
            isLoadingVideo = false
            
            if useFavoritesCache {
                preloadNextVideo()
            }
            
        } catch {
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
    
    func toggleFavorite() {
        if isFavorite {
            favoritePreparationTask?.cancel()
            favoritesRepository.removeFavorite(signId: sign.id)
            favoriteOfflineStatus = nil
            AnalyticsService.logSignUnfavorited(signId: sign.id, word: sign.word)
        } else {
            favoritesRepository.addFavorite(sign: sign, categoryName: categoryName)
            let requiredVideoIds = sign.videosArray.map(\.id)
            let initialStatus: FavoriteOfflineStatus = requiredVideoIds.isEmpty ? .readyOffline : .pending
            favoritesRepository.updateOfflineStatus(
                signId: sign.id,
                status: initialStatus,
                downloadedVideoIds: [],
                requiredVideoIds: requiredVideoIds
            )
            favoriteOfflineStatus = initialStatus
            if !requiredVideoIds.isEmpty {
                startOfflinePreparation(requiredVideoIds: requiredVideoIds)
            }
            AnalyticsService.logSignFavorited(signId: sign.id, word: sign.word)
        }
        isFavorite.toggle()
    }
    
    func checkFavoriteStatus() {
        isFavorite = favoritesRepository.isFavorite(signId: sign.id)
        favoriteOfflineStatus = favoritesRepository.getFavoriteEntry(signId: sign.id)?.offlineStatus
    }

    func loadCategoryName() async {
        do {
            let categories = try await signRepository.loadCategories()
            applyCategoryName(from: categories)
            if isFavorite {
                favoritesRepository.updateFavoriteSnapshot(sign: sign, categoryName: categoryName)
            }
        } catch {
            logger.warning("⚠️ Не удалось загрузить название категории: \(error.localizedDescription)")
        }
    }
    
    func cleanupVideo() {
        videoURL = nil
        logger.debug("🗑️ Видео ресурсы очищены для жеста \(self.sign.id)")
    }
    
    // MARK: - Synonym Navigation Methods
    
    func navigateToSign(_ signId: String) {
        lastRequestedSynonymId = signId
        isLoadingSynonym = true
        synonymError = nil
        
        Task {
            do {
                if let sign = try await signRepository.getSign(byId: signId) {
                    selectedSynonymSign = sign
                    isLoadingSynonym = false
                    synonymError = nil
                } else {
                    synonymError = "Жест не найден"
                    isLoadingSynonym = false
                }
            } catch {
                synonymError = "Не удалось загрузить жест: \(error.localizedDescription)"
                isLoadingSynonym = false
            }
        }
    }
    
    func retrySynonymLoad() {
        if let synonymId = lastRequestedSynonymId {
            navigateToSign(synonymId)
        }
    }
    
    // MARK: - Private Methods

    private func applyCategoryName(from categories: [Category]) {
        let categoryNamesById = CategoryDisplayDataHelper.categoryNamesById(
            from: CategoryDisplayDataHelper.sortedCategories(categories)
        )
        categoryName = CategoryDisplayDataHelper.name(for: sign.categoryId, in: categoryNamesById)
    }

    private func startOfflinePreparation(requiredVideoIds: [Int]) {
        favoritePreparationTask?.cancel()
        favoritePreparationTask = Task { [weak self] in
            guard let self else { return }
            let videos = sign.videosArray
            var downloadedVideoIds: [Int] = []

            for video in videos {
                guard !Task.isCancelled else { return }

                do {
                    _ = try await videoRepository.getVideoURL(for: video, useFavoritesCache: true)
                    downloadedVideoIds.append(video.id)
                } catch {
                    await MainActor.run {
                        guard self.favoritesRepository.isFavorite(signId: self.sign.id) else { return }
                        self.favoritesRepository.updateOfflineStatus(
                            signId: self.sign.id,
                            status: .failed,
                            downloadedVideoIds: downloadedVideoIds,
                            requiredVideoIds: requiredVideoIds
                        )
                        self.favoriteOfflineStatus = .failed
                        self.logger.warning("⚠️ Не удалось подготовить офлайн-видео для \(self.sign.id): \(error.localizedDescription)")
                    }
                    return
                }
            }

            await MainActor.run {
                guard self.favoritesRepository.isFavorite(signId: self.sign.id) else { return }
                self.favoritesRepository.updateOfflineStatus(
                    signId: self.sign.id,
                    status: .readyOffline,
                    downloadedVideoIds: downloadedVideoIds,
                    requiredVideoIds: requiredVideoIds
                )
                self.favoriteOfflineStatus = .readyOffline
            }
        }
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
