import Foundation

enum ConnectivityStatus: Equatable {
    case unknown
    case connected
    case disconnected
}

enum DataStatusReason: Equatable {
    case noInternet
    case serverUnavailable
}

enum LocalDataSource: Equatable {
    case memoryCache
    case diskCache
}

enum RepositoryDataStatus: Equatable {
    case idle
    case loading
    case availableLocally(LocalDataSource)
    case updated
    case upToDate
    case usingCachedData(DataStatusReason)
    case noData(DataStatusReason)
}

enum OfflineIndicatorStatus: Equatable {
    case noInternet
    case serverUnavailable

    var systemImageName: String {
        switch self {
        case .noInternet:
            return "wifi.slash"
        case .serverUnavailable:
            return "exclamationmark.circle"
        }
    }

    var title: String {
        switch self {
        case .noInternet:
            return "Нет интернета"
        case .serverUnavailable:
            return "Сервер недоступен"
        }
    }
}

enum AppStartupStatus: Equatable {
    case idle
    case loading
    case ready
    case readyUsingCachedData
    case blocked(DataStatusReason)

    var isReady: Bool {
        switch self {
        case .ready, .readyUsingCachedData:
            return true
        case .idle, .loading, .blocked:
            return false
        }
    }
}
