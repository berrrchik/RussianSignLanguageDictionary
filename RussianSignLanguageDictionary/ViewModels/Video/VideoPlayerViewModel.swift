import Foundation
import AVKit
import os.log

/// ViewModel для управления AVPlayer в VideoPlayerView
///
/// Управляет жизненным циклом AVPlayer, состоянием готовности к воспроизведению
/// и обработкой loop для видео.
@MainActor
final class VideoPlayerViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isReadyToPlay = false
    @Published private(set) var playbackErrorMessage: String?
    
    // MARK: - Properties
    
    private static let remoteLoadTimeout: TimeInterval = 15
    
    private let logger = Logger(subsystem: "com.rsl.videoPlayer", category: "VideoPlayerViewModel")
    
    private var loopObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var setupTask: Task<Void, Never>?
    
    // MARK: - Public Methods
    
    /// Настраивает player для указанного URL
    /// - Parameter url: URL видео (локальный файл или remote URL)
    func setupPlayer(for url: URL) {
        cleanupPlayer()
        playbackErrorMessage = nil
        
        if url.isFileURL {
            setupLocalPlayer(url: url)
        } else {
            setupRemotePlayer(url: url)
        }
    }
    
    /// Очищает ресурсы player
    func cleanupPlayer() {
        setupTask?.cancel()
        setupTask = nil
        player?.pause()
        
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        
        statusObserver?.invalidate()
        statusObserver = nil
        
        player = nil
        isReadyToPlay = false
        playbackErrorMessage = nil
    }
    
    // MARK: - Private Methods
    
    /// Настройка player для локального файла
    private func setupLocalPlayer(url: URL) {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.actionAtItemEnd = .none
        
        setupLoopObserver(for: playerItem, player: newPlayer)
        player = newPlayer
        observePlayerItemStatus(playerItem, player: newPlayer)
    }
    
    /// Настройка player для удалённого URL (асинхронно, с loading)
    private func setupRemotePlayer(url: URL) {
        isReadyToPlay = false
        playbackErrorMessage = nil
        
        setupTask = Task {
            let asset = AVURLAsset(url: url)
            
            do {
                let isPlayable = try await loadPlayableStatus(for: asset)
                guard !Task.isCancelled else { return }
                
                guard isPlayable else {
                    reportPlaybackFailure()
                    return
                }
                
                let playerItem = AVPlayerItem(asset: asset)
                let newPlayer = AVPlayer(playerItem: playerItem)
                newPlayer.actionAtItemEnd = .none
                
                setupLoopObserver(for: playerItem, player: newPlayer)
                player = newPlayer
                observePlayerItemStatus(playerItem, player: newPlayer)
            } catch {
                guard !Task.isCancelled else { return }
                logger.error("❌ Ошибка загрузки ассета: \(error.localizedDescription)")
                reportPlaybackFailure(error)
            }
        }
    }
    
    private func observePlayerItemStatus(_ playerItem: AVPlayerItem, player: AVPlayer) {
        statusObserver = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                
                switch item.status {
                case .readyToPlay:
                    self.playbackErrorMessage = nil
                    self.isReadyToPlay = true
                    player.play()
                case .failed:
                    self.reportPlaybackFailure(item.error)
                default:
                    break
                }
            }
        }
    }
    
    private func loadPlayableStatus(for asset: AVURLAsset) async throws -> Bool {
        try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                try await asset.load(.isPlayable)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(Self.remoteLoadTimeout * 1_000_000_000))
                throw VideoRepositoryError.videoUnavailable
            }
            
            guard let result = try await group.next() else {
                throw VideoRepositoryError.videoUnavailable
            }
            group.cancelAll()
            return result
        }
    }
    
    private func reportPlaybackFailure(_ error: Error? = nil) {
        setupTask?.cancel()
        setupTask = nil
        isReadyToPlay = false
        player?.pause()
        playbackErrorMessage = Self.message(for: error)
    }
    
    private static func message(for error: Error?) -> String {
        if let videoError = error as? VideoRepositoryError {
            return ErrorMessageMapper.message(for: videoError)
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return ErrorMessageMapper.message(for: VideoRepositoryError.noInternetConnection)
            case .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .badServerResponse:
                return ErrorMessageMapper.message(for: VideoRepositoryError.videoUnavailable)
            default:
                return ErrorMessageMapper.message(for: VideoRepositoryError.videoUnavailable)
            }
        }
        
        return ErrorMessageMapper.message(for: VideoRepositoryError.videoUnavailable)
    }
    
    /// Настраивает observer для loop видео
    private func setupLoopObserver(for playerItem: AVPlayerItem, player: AVPlayer) {
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }
}
