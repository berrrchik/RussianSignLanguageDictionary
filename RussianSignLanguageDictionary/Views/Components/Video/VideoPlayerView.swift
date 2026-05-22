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
    
    @StateObject private var viewModel = VideoPlayerViewModel()
    
    init(videoURL: URL, orientation: VideoOrientation = .vertical) {
        self.videoURL = videoURL
        self.orientation = orientation
    }
    
    var body: some View {
        ZStack {
            if let errorMessage = viewModel.playbackErrorMessage {
                ErrorView(
                    message: errorMessage,
                    retryAction: { viewModel.setupPlayer(for: videoURL) }
                )
            } else if let player = viewModel.player, viewModel.isReadyToPlay {
                VideoPlayer(player: player)
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .cornerRadius(LayoutConstants.VideoPlayer.cornerRadius)
                    .onDisappear {
                        viewModel.cleanupPlayer()
                    }
            } else {
                LoadingView(message: "Загрузка видео...")
            }
        }
        .onAppear {
            viewModel.setupPlayer(for: videoURL)
        }
        .onChange(of: videoURL) { newURL in
            viewModel.setupPlayer(for: newURL)
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
}

// MARK: - Preview

struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerView(videoURL: URL(string: "https://example.com/video.mp4")!)
            .frame(height: 400)
            .padding()
    }
}

