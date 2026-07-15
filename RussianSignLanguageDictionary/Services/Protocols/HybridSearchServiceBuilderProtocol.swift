import Foundation

protocol HybridSearchServiceBuilderProtocol: Sendable {
    func make(
        signs: [Sign],
        networkMonitor: NetworkMonitorProtocol
    ) -> HybridSearchServiceProtocol
}
