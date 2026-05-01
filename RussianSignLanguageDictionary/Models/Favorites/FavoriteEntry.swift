import Foundation

enum FavoriteOfflineStatus: String, Codable, Equatable {
    case pending
    case readyOffline
    case failed

    var displayText: String {
        switch self {
        case .pending:
            return "Подготавливается для офлайн"
        case .readyOffline:
            return "Доступно офлайн"
        case .failed:
            return "Не удалось подготовить офлайн"
        }
    }
}

struct FavoriteOfflineVideo: Identifiable, Codable, Hashable {
    let videoId: Int

    var id: Int { videoId }
}

struct FavoriteSignSnapshot: Codable, Hashable {
    let sign: Sign
    let categoryName: String
}

struct FavoriteEntry: Identifiable, Codable, Hashable {
    let signId: String
    var snapshot: FavoriteSignSnapshot?
    var offlineStatus: FavoriteOfflineStatus
    var requiredVideoIds: [Int]
    var downloadedVideos: [FavoriteOfflineVideo]
    let addedAt: Date
    var updatedAt: Date

    var id: String { signId }

    init(
        signId: String,
        snapshot: FavoriteSignSnapshot? = nil,
        offlineStatus: FavoriteOfflineStatus = .pending,
        requiredVideoIds: [Int] = [],
        downloadedVideos: [FavoriteOfflineVideo] = [],
        addedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.signId = signId
        self.snapshot = snapshot
        self.offlineStatus = offlineStatus
        self.requiredVideoIds = requiredVideoIds
        self.downloadedVideos = downloadedVideos
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }
}
