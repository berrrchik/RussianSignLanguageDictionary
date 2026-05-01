import Foundation

enum VideoSessionFactory {
    static let requestTimeout: TimeInterval = 10
    static let resourceTimeout: TimeInterval = 20

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = false
        configuration.allowsCellularAccess = true
        return URLSession(configuration: configuration)
    }
}
