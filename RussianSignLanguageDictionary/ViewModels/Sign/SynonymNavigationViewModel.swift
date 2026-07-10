import Foundation

/// Управляет загрузкой и навигацией по синонимам жеста.
/// Выделен из `SignDetailViewModel` как самостоятельная зона ответственности —
/// не пересекается с видео и статусом избранного.
@MainActor
final class SynonymNavigationViewModel: ObservableObject {
    @Published var selectedSign: Sign?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    private var lastRequestedSignId: String?
    private let signRepository: SignRepositoryProtocol

    init(signRepository: SignRepositoryProtocol) {
        self.signRepository = signRepository
    }

    func navigateToSign(_ signId: String) {
        lastRequestedSignId = signId
        isLoading = true
        errorMessage = nil

        Task {
            let result: Result<Sign?, Error>
            do {
                result = .success(try await signRepository.getSign(byId: signId))
            } catch {
                result = .failure(error)
            }

            // Более новый запрос уже мог перезаписать lastRequestedSignId —
            // отбрасываем ответ на устаревший запрос, чтобы не показать не тот жест.
            guard lastRequestedSignId == signId else { return }

            switch result {
            case .success(let sign?):
                selectedSign = sign
                isLoading = false
                errorMessage = nil
            case .success(nil):
                errorMessage = "Жест не найден"
                isLoading = false
            case .failure(let error):
                errorMessage = ErrorMessageMapper.message(for: error)
                isLoading = false
            }
        }
    }

    func retry() {
        if let signId = lastRequestedSignId {
            navigateToSign(signId)
        }
    }
}
