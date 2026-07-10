import Foundation

/// Координирует hybrid/text/local поиск, оставляя `SearchViewModel`
/// только управление экранным состоянием и загрузкой данных.
@MainActor
final class SearchCoordinator {
    struct SearchOutcome {
        let results: [Sign]
        let analyticsSearchType: String?
    }

    private struct SearchableSign {
        let sign: Sign
        let lowercasedWord: String
    }

    private let networkMonitor: NetworkMonitorProtocol
    private let hybridSearchServiceBuilder: HybridSearchServiceBuilderProtocol
    private var hybridSearchService: HybridSearchServiceProtocol?
    private var searchableSigns: [SearchableSign] = []

    init(
        networkMonitor: NetworkMonitorProtocol,
        hybridSearchServiceBuilder: HybridSearchServiceBuilderProtocol
    ) {
        self.networkMonitor = networkMonitor
        self.hybridSearchServiceBuilder = hybridSearchServiceBuilder
    }

    func updateSearchData(with signs: [Sign]) {
        searchableSigns = signs.map { sign in
            SearchableSign(
                sign: sign,
                lowercasedWord: sign.word.lowercased()
            )
        }

        hybridSearchService = hybridSearchServiceBuilder.make(
            signs: signs,
            networkMonitor: networkMonitor
        )
    }

    func performSearch(query: String) async -> SearchOutcome? {
        if let hybridSearchService {
            return await executeHybridSearch(query, service: hybridSearchService)
        }

        return executeLocalSearch(query)
    }

    private func executeHybridSearch(
        _ query: String,
        service: HybridSearchServiceProtocol
    ) async -> SearchOutcome? {
        do {
            let results = try await runHybridSearch(query, service: service)
            guard !Task.isCancelled else { return nil }
            return SearchOutcome(results: results, analyticsSearchType: "hybrid")
        } catch {
            guard !Task.isCancelled else { return nil }
            CrashlyticsErrorReporter.capture(
                error,
                context: ["query": query],
                subsystem: "com.rsl.search"
            )
            let textResults = runTextSearchFallback(query, service: service)
            guard !Task.isCancelled else { return nil }
            return SearchOutcome(results: textResults, analyticsSearchType: "text")
        }
    }

    private func runHybridSearch(
        _ query: String,
        service: HybridSearchServiceProtocol
    ) async throws -> [Sign] {
        try await service.performHybridSearch(
            query: query,
            limit: 50,
            useHighQualityThreshold: false
        )
    }

    private func runTextSearchFallback(
        _ query: String,
        service: HybridSearchServiceProtocol
    ) -> [Sign] {
        service.performTextSearch(query: query, limit: 50)
    }

    private func executeLocalSearch(_ query: String) -> SearchOutcome? {
        let lowercasedQuery = query.lowercased()
        let filtered = searchableSigns.filter { $0.lowercasedWord.contains(lowercasedQuery) }
        guard !Task.isCancelled else { return nil }
        return SearchOutcome(results: filtered.map(\.sign), analyticsSearchType: nil)
    }
}
