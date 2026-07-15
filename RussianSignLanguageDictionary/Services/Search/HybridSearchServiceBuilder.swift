import Foundation

final class HybridSearchServiceBuilder: HybridSearchServiceBuilderProtocol, Sendable {
    private let baseURL: URL

    init(baseURL: URL = APIConfig.apiBaseURL) {
        self.baseURL = baseURL
    }

    func make(
        signs: [Sign],
        networkMonitor: NetworkMonitorProtocol
    ) -> HybridSearchServiceProtocol {
        HybridSearchService(
            baseURL: baseURL,
            signs: signs,
            networkMonitor: networkMonitor,
            sbertService: SBERTSearchService(baseURL: baseURL)
        )
    }
}
