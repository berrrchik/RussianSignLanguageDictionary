import Foundation

protocol HybridSearchServiceProtocol {
    func performHybridSearch(
        query: String,
        limit: Int,
        useHighQualityThreshold: Bool
    ) async throws -> [Sign]

    func performTextSearch(query: String, limit: Int) -> [Sign]
}
