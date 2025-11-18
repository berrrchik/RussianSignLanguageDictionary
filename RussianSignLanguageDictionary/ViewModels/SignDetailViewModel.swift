import Foundation


@MainActor
final class SignDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var videoURL: URL?
    @Published private(set) var isLoadingVideo: Bool = false
    @Published private(set) var videoErrorMessage: String?
    @Published var isFavorite: Bool = false
    
    // MARK: - Properties
    
    let sign: Sign
    
    // MARK: - Dependencies
    
    private let videoRepository: VideoRepositoryProtocol
    private let favoritesRepository: FavoritesRepositoryProtocol
    
    // MARK: - Init
    
    init(
        sign: Sign,
        videoRepository: VideoRepositoryProtocol,
        favoritesRepository: FavoritesRepositoryProtocol
    ) {
        self.sign = sign
        self.videoRepository = videoRepository
        self.favoritesRepository = favoritesRepository
        self.isFavorite = favoritesRepository.isFavorite(signId: sign.id)
    }
    
    // MARK: - Public Methods
    
    func loadVideo() async {
        isLoadingVideo = true
        videoErrorMessage = nil
        
        do {
            let url = try await videoRepository.getVideoURL(for: sign)
            videoURL = url
            isLoadingVideo = false
        } catch {
            videoErrorMessage = ErrorMessageMapper.message(for: error)
            isLoadingVideo = false
        }
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
}

