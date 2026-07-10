import Foundation

/// Грубая классификация `URLError` на "нет интернета" / "недоступно",
/// общая для всех мест, где сетевая ошибка загрузки видео мапится в доменную ошибку.
enum URLErrorNetworkOutcome: Equatable {
    case noInternet
    case unavailable
}

enum URLErrorClassifier {
    static func classify(_ urlError: URLError) -> URLErrorNetworkOutcome {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noInternet
        default:
            return .unavailable
        }
    }
}
