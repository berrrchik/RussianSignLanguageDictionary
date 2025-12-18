import Foundation
import os.log

@MainActor
final class SignDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentVideoIndex: Int = 0
    @Published private(set) var videoURL: URL?
    @Published private(set) var isLoadingVideo: Bool = false
    @Published private(set) var videoErrorMessage: String?
    @Published var isFavorite: Bool = false
    
    // MARK: - Synonym Navigation Properties
    
    @Published var selectedSynonymSign: Sign?
    @Published private(set) var isLoadingSynonym: Bool = false
    @Published private(set) var synonymError: String?
    private var lastRequestedSynonymId: String?
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.signDetail", category: "SignDetailViewModel")
    
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
    
    /// Следующее видео в списке (для предзагрузки)
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
    }
    
    // MARK: - Public Methods
    
    /// Загружает видео с автоматическим определением типа кеша
    ///
    /// Если жест в избранном - использует долгосрочный кеш (URLCache на диске),
    /// иначе - краткосрочный кеш AVPlayer (в памяти).
    func loadVideo() async {
        guard let video = currentVideo else { return }
        
        isLoadingVideo = true
        videoErrorMessage = nil
        
        // Автоматическое определение типа кеша на основе статуса избранного
        let useFavoritesCache = favoritesRepository.isFavorite(signId: sign.id)
        
        do {
            let url = try await videoRepository.getVideoURL(
                for: video,
                useFavoritesCache: useFavoritesCache
            )
            videoURL = url
            isLoadingVideo = false
            
            // Предзагрузка следующего видео для избранных жестов
            if useFavoritesCache {
                preloadNextVideo()
            }
            
        } catch {
            videoErrorMessage = ErrorMessageMapper.message(for: error)
            isLoadingVideo = false
            logger.error("❌ Ошибка загрузки видео: \(error.localizedDescription)")
        }
    }
    
    func showNextVideo() {
        guard canGoNext else { return }
        currentVideoIndex += 1
        // loadVideo() будет вызван автоматически через onChange в SignDetailView
    }
    
    func showPreviousVideo() {
        guard canGoBack else { return }
        currentVideoIndex -= 1
        // loadVideo() будет вызван автоматически через onChange в SignDetailView
    }
    
    func toggleFavorite() {
        if isFavorite {
            favoritesRepository.removeFavorite(signId: sign.id)
        } else {
            favoritesRepository.addFavorite(signId: sign.id)
        }
        isFavorite.toggle()
    }
    
    func checkFavoriteStatus() {
        isFavorite = favoritesRepository.isFavorite(signId: sign.id)
    }
    
    /// Очистка ресурсов видео при выходе из экрана
    ///
    /// Освобождает память от краткосрочного кеша AVPlayer.
    /// Долгосрочный кеш для избранных жестов сохраняется.
    func cleanupVideo() {
        videoURL = nil
        logger.debug("🗑️ Видео ресурсы очищены для жеста \(self.sign.id)")
    }
    
    // MARK: - Synonym Navigation Methods
    
    /// Навигация к жесту-синониму
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
    
    /// Повторная попытка загрузки последнего запрошенного синонима
    func retrySynonymLoad() {
        if let synonymId = lastRequestedSynonymId {
            navigateToSign(synonymId)
        }
    }
    
    // MARK: - Private Methods
    
    /// Предзагрузка следующего видео в фоне для избранных жестов
    ///
    /// Ускоряет переключение между видео за счёт предварительной загрузки.
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

