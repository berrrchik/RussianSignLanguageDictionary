import Foundation

protocol HybridSearchServiceBuilderProtocol {
    func make(
        signs: [Sign],
        networkMonitor: NetworkMonitorProtocol
    ) -> HybridSearchServiceProtocol
}
