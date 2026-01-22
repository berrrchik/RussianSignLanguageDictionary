import SwiftUI
import AVKit

/// Ориентация видео
enum VideoOrientation {
    case vertical
    case horizontal 
}

struct VideoPlayerView: View {
    let videoURL: URL
    let orientation: VideoOrientation
    
    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol?
    @State private var isReadyToPlay = false
    
    init(videoURL: URL, orientation: VideoOrientation = .vertical) {
        self.videoURL = videoURL
        self.orientation = orientation
    }
    
    var body: some View {
        ZStack {
            if let player = player, isReadyToPlay {
                VideoPlayer(player: player)
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .cornerRadius(LayoutConstants.VideoPlayer.cornerRadius)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        cleanupPlayer()
                    }
            } else {
                LoadingView(message: "Загрузка видео...")
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onChange(of: videoURL) { _ in
            setupPlayer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var aspectRatio: CGFloat {
        switch orientation {
        case .vertical:
            return LayoutConstants.VideoPlayer.verticalAspectRatio
        case .horizontal:
            return LayoutConstants.VideoPlayer.horizontalAspectRatio
        }
    }
    
    // MARK: - Private Methods
    
    private func setupPlayer() {
        cleanupPlayer()
        isReadyToPlay = false
        
        // Используем AVURLAsset для асинхронной загрузки метаданных
        let asset = AVURLAsset(url: videoURL)
        
        Task {
            // Асинхронно загружаем необходимые свойства перед воспроизведением
            do {
                let isPlayable = try await asset.load(.isPlayable)
                guard isPlayable else { return }
                
                await MainActor.run {
                    let playerItem = AVPlayerItem(asset: asset)
                    let newPlayer = AVPlayer(playerItem: playerItem)
                    newPlayer.actionAtItemEnd = .none
                    
                    loopObserver = NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: playerItem,
                        queue: .main
                    ) { _ in
                        newPlayer.seek(to: .zero)
                        newPlayer.play()
                    }
                    
                    self.player = newPlayer
                    self.isReadyToPlay = true
                    newPlayer.play()
                }
            } catch {
                // Ошибка загрузки ассета — показываем LoadingView
            }
        }
    }
    
    private func cleanupPlayer() {
        player?.pause()
        
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        
        player = nil
        isReadyToPlay = false
    }
}

// MARK: - Preview

struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerView(videoURL: URL(string: "https://example.com/video.mp4")!)
            .frame(height: 400)
            .padding()
    }
}

