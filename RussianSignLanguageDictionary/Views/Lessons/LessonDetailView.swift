import SwiftUI

struct LessonDetailView: View {
    @StateObject private var viewModel: LessonDetailViewModel

    init(lesson: Lesson) {
        _viewModel = StateObject(wrappedValue: LessonDetailViewModel(lesson: lesson))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                videoPlayerView
                descriptionView
            }
            .padding(.bottom, 16)
        }
        .navigationTitle(viewModel.lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBackButton()
        .onAppear {
            AnalyticsService.logLessonViewed(lessonId: viewModel.lesson.id, lessonTitle: viewModel.lesson.title)
        }
        .task {
            await viewModel.loadVideo()
        }
    }

    // MARK: - Subviews
    
    @ViewBuilder
    private var videoPlayerView: some View {
        Group {
            if viewModel.isLoadingVideo {
                LoadingView(message: "Загрузка видео...")
            } else if let errorMessage = viewModel.videoErrorMessage {
                ErrorView(
                    message: errorMessage,
                    retryAction: { Task { await viewModel.loadVideo() } }
                )
            } else if let videoURL = viewModel.videoURL {
                VideoPlayerView(videoURL: videoURL, orientation: .horizontal)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(LayoutConstants.VideoPlayer.horizontalAspectRatio, contentMode: .fit)
        .padding(.horizontal, LayoutConstants.VideoPlayer.horizontalPadding)
    }
    
    private var descriptionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Описание")
                .font(.headline)
            
            Text(viewModel.lesson.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#if DEBUG
struct LessonDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LessonDetailView(lesson: PreviewData.lesson)
        }
        .environment(\.dependencies, .preview)
    }
}
#endif
