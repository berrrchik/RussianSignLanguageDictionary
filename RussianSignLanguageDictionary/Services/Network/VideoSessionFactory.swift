import Foundation

enum VideoSessionFactory {
    static let requestTimeout: TimeInterval = 5
    static let resourceTimeout: TimeInterval = 12

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = false
        configuration.allowsCellularAccess = true
        return URLSession(configuration: configuration)
    }
}
