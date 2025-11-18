import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol?
    
    init(videoURL: URL) {
        self.videoURL = videoURL
    }
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(LayoutConstants.VideoPlayer.verticalAspectRatio, contentMode: .fit)
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
    }
    
    // MARK: - Private Methods
    
    private func setupPlayer() {
        let playerItem = AVPlayerItem(url: videoURL)
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
    }
    
    private func cleanupPlayer() {
        player?.pause()
        
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        
        player = nil
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

