import Foundation
import os.log

/// Репозиторий для синхронизации данных с сервером
/// Использует Raw API endpoints для получения данных
final class SyncRepository: SyncRepositoryProtocol {
    // MARK: - Properties
    
    private let baseURL: URL
    private let session: URLSession
    private let etagManager: ETagManager
    private let responseHandler: HTTPResponseHandler
    private let logger = Logger(subsystem: "com.rsl.SyncRepository", category: "sync")
    
    // MARK: - Initialization
    
    init(
        baseURL: URL = APIConfig.baseURL,
        session: URLSession? = nil,
        etagManager: ETagManager = ETagManager(),
        responseHandler: HTTPResponseHandler = HTTPResponseHandler()
    ) {
        self.baseURL = baseURL
        self.etagManager = etagManager
        self.responseHandler = responseHandler
        self.session = session ?? Self.createDefaultSession()
    }
    
    // MARK: - SyncRepositoryProtocol
    
    func checkForUpdates(lastUpdated: Date?) async throws -> SyncMetadata {
        let url = SyncEndpoints.checkUpdates(lastUpdated: lastUpdated).url(baseURL: baseURL)
        
        return try await performRequest(
            url: url,
            etagKey: .syncCheck,
            notModifiedHandler: {
                SyncMetadata(lastUpdated: lastUpdated ?? Date(), hasUpdates: false)
            }
        )
    }
    
    func fetchAllData(cachedDataProvider: @escaping () throws -> SyncData) async throws -> SyncData {
        let url = SyncEndpoints.fetchData.url(baseURL: baseURL)
        
        return try await performRequest(
            url: url,
            etagKey: .syncData,
            notModifiedHandler: cachedDataProvider
        )
    }
    
    // MARK: - Generic Request Handler
    
    private func performRequest<T: Decodable>(
        url: URL,
        etagKey: ETagManager.StorageKey,
        notModifiedHandler: () throws -> T
    ) async throws -> T {
        let cachedETag = etagManager.getETag(for: etagKey)
        let request = buildRequest(url: url, etag: cachedETag)
        
        let (data, response) = try await executeRequest(request)
        
        switch responseHandler.handle(response: response, data: data) {
        case .notModified:
            return try notModifiedHandler()
            
        case .success(let responseData):
            saveETagIfPresent(from: response, key: etagKey)
            return try decode(responseData)
            
        case .error(let error):
            throw error
        }
    }
    
    // MARK: - Network Execution
    
    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw SyncError.from(error)
        }
    }
    
    // MARK: - Request Building
    
    private func buildRequest(url: URL, etag: String?) -> URLRequest {
        var request = URLRequest(url: url)
        if let etag = etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        return request
    }
    
    // MARK: - ETag Processing
    
    private func saveETagIfPresent(from response: URLResponse, key: ETagManager.StorageKey) {
        guard let etag = responseHandler.extractETag(from: response) else { return }
        etagManager.saveETag(etag, for: key)
    }
    
    // MARK: - Decoding
    
    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try APIJSONDecoder.shared.decode(T.self, from: data)
        } catch let error as DecodingError {
            DecodingErrorLogger.log(error, data: data, logger: logger)
            throw SyncError.decodingError(error)
        }
    }
    
    // MARK: - Session Configuration
    
    private static func createDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 120.0
        config.allowsCellularAccess = true
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }
}
