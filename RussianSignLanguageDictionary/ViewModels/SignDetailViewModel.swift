import Foundation

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
    
    func loadVideo() async {
        guard let video = currentVideo else { return }
        
        isLoadingVideo = true
        videoErrorMessage = nil
        
        do {
            let url = try await videoRepository.getVideoURL(for: video)
            videoURL = url
            isLoadingVideo = false
        } catch {
            videoErrorMessage = ErrorMessageMapper.message(for: error)
            isLoadingVideo = false
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
}

