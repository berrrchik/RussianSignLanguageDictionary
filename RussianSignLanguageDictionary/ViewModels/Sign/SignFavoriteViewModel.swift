import Foundation

/// Управляет статусом "избранное" и офлайн-подготовкой видео для одного жеста.
/// Выделен из `SignDetailViewModel`, чтобы отделить эту зону ответственности
/// от воспроизведения видео и навигации по синонимам.
@MainActor
final class SignFavoriteViewModel: ObservableObject {
    @Published private(set) var isFavorite: Bool
    @Published private(set) var offlineStatus: FavoriteOfflineStatus?

    private let sign: Sign
    private let favoritesRepository: FavoritesRepositoryProtocol
    private let offlinePreparationService: OfflinePreparationServiceProtocol
    private var preparationTask: Task<Void, Never>?
    private var statusCheckTask: Task<Void, Never>?

    init(
        sign: Sign,
        favoritesRepository: FavoritesRepositoryProtocol,
        offlinePreparationService: OfflinePreparationServiceProtocol
    ) {
        self.sign = sign
        self.favoritesRepository = favoritesRepository
        self.offlinePreparationService = offlinePreparationService
        self.isFavorite = favoritesRepository.isFavorite(signId: sign.id)
        self.offlineStatus = favoritesRepository.getFavoriteEntry(signId: sign.id)?.offlineStatus
    }

    deinit {
        preparationTask?.cancel()
        statusCheckTask?.cancel()
    }

    func toggle(categoryName: String) {
        if isFavorite {
            preparationTask?.cancel()
            favoritesRepository.removeFavorite(signId: sign.id)
            offlineStatus = nil
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
            offlineStatus = initialStatus
            if !requiredVideoIds.isEmpty {
                startOfflinePreparation(categoryName: categoryName)
            }
            AnalyticsService.logSignFavorited(signId: sign.id, word: sign.word)
        }
        isFavorite.toggle()
    }

    func checkStatus() {
        statusCheckTask?.cancel()
        let favoritesRepository = self.favoritesRepository
        let signId = sign.id
        statusCheckTask = Task { [weak self] in
            await favoritesRepository.reconcileOfflineState()
            guard let self else { return }
            self.isFavorite = favoritesRepository.isFavorite(signId: signId)
            self.offlineStatus = favoritesRepository.getFavoriteEntry(signId: signId)?.offlineStatus
        }
    }

    func updateSnapshotIfFavorite(categoryName: String) {
        if isFavorite {
            favoritesRepository.updateFavoriteSnapshot(sign: sign, categoryName: categoryName)
        }
    }

    private func startOfflinePreparation(categoryName: String) {
        preparationTask?.cancel()
        let offlinePreparationService = self.offlinePreparationService
        let sign = self.sign
        preparationTask = Task { [weak self] in
            let outcome = await offlinePreparationService.prepare(sign: sign, categoryName: categoryName)
            guard let self else { return }
            switch outcome {
            case .readyOffline:
                self.offlineStatus = .readyOffline
            case .failed:
                self.offlineStatus = .failed
            case .cancelled:
                break
            }
        }
    }
}
