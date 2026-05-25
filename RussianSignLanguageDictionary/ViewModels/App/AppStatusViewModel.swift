import Foundation
import Combine

@MainActor
final class AppStatusViewModel: ObservableObject {
    @Published private(set) var connectivityStatus: ConnectivityStatus
    @Published private(set) var repositoryDataStatus: RepositoryDataStatus
    @Published private(set) var indicatorStatus: OfflineIndicatorStatus?

    private var cancellables = Set<AnyCancellable>()

    convenience init() {
        let container = DIContainer.shared
        self.init(
            signRepository: container.resolve(SignRepositoryProtocol.self),
            networkMonitor: container.resolve(NetworkMonitorProtocol.self)
        )
    }

    init(
        signRepository: SignRepositoryProtocol,
        networkMonitor: NetworkMonitorProtocol
    ) {
        connectivityStatus = networkMonitor.connectivityStatus
        repositoryDataStatus = signRepository.currentDataStatus
        indicatorStatus = Self.makeIndicatorStatus(
            connectivityStatus: connectivityStatus,
            repositoryDataStatus: repositoryDataStatus
        )

        signRepository.dataStatusPublisher
            .sink { [weak self] status in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    repositoryDataStatus = status
                    refreshIndicator()
                }
            }
            .store(in: &cancellables)

        networkMonitor.connectivityPublisher
            .sink { [weak self] status in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    connectivityStatus = status
                    refreshIndicator()
                }
            }
            .store(in: &cancellables)
    }

    private func refreshIndicator() {
        indicatorStatus = Self.makeIndicatorStatus(
            connectivityStatus: connectivityStatus,
            repositoryDataStatus: repositoryDataStatus
        )
    }

    private static func makeIndicatorStatus(
        connectivityStatus: ConnectivityStatus,
        repositoryDataStatus: RepositoryDataStatus
    ) -> OfflineIndicatorStatus? {
        switch repositoryDataStatus {
        case .usingCachedData(.serverUnavailable):
            return .serverUnavailable
        case .usingCachedData(.noInternet):
            return .noInternet
        case .noData:
            return nil
        case .idle, .loading, .availableLocally, .updated, .upToDate:
            return connectivityStatus == .disconnected ? .noInternet : nil
        }
    }
}
