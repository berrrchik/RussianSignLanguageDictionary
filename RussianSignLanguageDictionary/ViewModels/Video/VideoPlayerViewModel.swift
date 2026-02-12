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
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.videoPlayer", category: "VideoPlayerViewModel")
    
    private var loopObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    
    // MARK: - Public Methods
    
    /// Настраивает player для указанного URL
    /// - Parameter url: URL видео (локальный файл или remote URL)
    func setupPlayer(for url: URL) {
        cleanupPlayer()
        
        if url.isFileURL {
            setupLocalPlayer(url: url)
        } else {
            setupRemotePlayer(url: url)
        }
    }
    
    /// Очищает ресурсы player
    func cleanupPlayer() {
        player?.pause()
        
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        
        statusObserver?.invalidate()
        statusObserver = nil
        
        player = nil
        isReadyToPlay = false
    }
    
    // MARK: - Private Methods
    
    /// Настройка player для локального файла
    ///
    /// Для локальных файлов AVPlayer готовится почти мгновенно,
    /// но корректно наблюдаем `playerItem.status` через KVO
    /// вместо ложного `isReadyToPlay = true` до реальной готовности.
    private func setupLocalPlayer(url: URL) {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.actionAtItemEnd = .none
        
        setupLoopObserver(for: playerItem, player: newPlayer)
        self.player = newPlayer
        
        // KVO на status: для локальных файлов .readyToPlay наступает почти мгновенно
        statusObserver = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    self.isReadyToPlay = true
                    newPlayer.play()
                }
            }
        }
    }
    
    /// Настройка player для удалённого URL (асинхронно, с loading)
    private func setupRemotePlayer(url: URL) {
        isReadyToPlay = false
        
        let asset = AVURLAsset(url: url)
        let logger = self.logger
        
        Task {
            do {
                let isPlayable = try await asset.load(.isPlayable)
                guard isPlayable else { return }
                
                await MainActor.run {
                    let playerItem = AVPlayerItem(asset: asset)
                    let newPlayer = AVPlayer(playerItem: playerItem)
                    newPlayer.actionAtItemEnd = .none
                    
                    self.setupLoopObserver(for: playerItem, player: newPlayer)
                    self.player = newPlayer
                    self.isReadyToPlay = true
                    newPlayer.play()
                }
            } catch {
                logger.error("❌ Ошибка загрузки ассета: \(error.localizedDescription)")
            }
        }
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
