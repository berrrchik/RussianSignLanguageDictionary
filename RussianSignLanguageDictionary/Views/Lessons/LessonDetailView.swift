import SwiftUI

struct LessonDetailView: View {
    @StateObject private var viewModel: LessonDetailViewModel
    @State private var selectedLesson: Lesson?
    
    let lesson: Lesson
    let allLessons: [Lesson]
    let videoRepository: VideoRepositoryProtocol

    init(lesson: Lesson, allLessons: [Lesson], videoRepository: VideoRepositoryProtocol) {
        self.lesson = lesson
        self.allLessons = allLessons
        self.videoRepository = videoRepository
        _viewModel = StateObject(wrappedValue: LessonDetailViewModel(
            lesson: lesson,
            allLessons: allLessons,
            videoRepository: videoRepository
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                videoPlayerView
                descriptionView
                navigationView
            }
            .padding(.bottom, 16)
        }
        .navigationTitle(viewModel.lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadVideo()
        }
        .navigationDestination(item: $selectedLesson) { lesson in
            LessonDetailView(
                lesson: lesson,
                allLessons: allLessons,
                videoRepository: videoRepository
            )
        }
    }

    // MARK: - Subviews
    
    @ViewBuilder
    private var videoPlayerView: some View {
        if viewModel.isLoadingVideo {
            videoPlaceholder
                .overlay {
                    LoadingView(message: "Загрузка видео...")
                }
        } else if let errorMessage = viewModel.videoErrorMessage {
            videoPlaceholder
                .overlay {
                    ErrorView(message: errorMessage)
                }
        } else if let videoURL = viewModel.videoURL {
            VideoPlayerView(videoURL: videoURL, orientation: .horizontal)
        } else {
            videoPlaceholder
        }
    }
    
    private var videoPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .aspectRatio(LayoutConstants.VideoPlayer.horizontalAspectRatio, contentMode: .fit)
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
    
    @ViewBuilder
    private var navigationView: some View {
        if viewModel.canGoBack || viewModel.canGoNext {
            HStack(spacing: 16) {
                if viewModel.canGoBack {
                    Button(action: { selectedLesson = viewModel.showPreviousLesson() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Предыдущий")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if viewModel.canGoNext {
                    Button(action: { selectedLesson = viewModel.showNextLesson() }) {
                        HStack(spacing: 4) {
                            Text("Следующий")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
        }
    }
}
