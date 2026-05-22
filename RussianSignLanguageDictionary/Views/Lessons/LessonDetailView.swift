import SwiftUI

struct LessonDetailView: View {
    @StateObject private var viewModel: LessonDetailViewModel
    @State private var selectedLesson: Lesson?
    
    private let allLessons: [Lesson]

    init(lesson: Lesson, allLessons: [Lesson]) {
        self.allLessons = allLessons
        _viewModel = StateObject(wrappedValue: LessonDetailViewModel(
            lesson: lesson,
            allLessons: allLessons
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
        .navigationBackButton()
        .onAppear {
            AnalyticsService.logLessonViewed(lessonId: viewModel.lesson.id, lessonTitle: viewModel.lesson.title)
        }
        .task {
            await viewModel.loadVideo()
        }
        .navigationDestination(item: $selectedLesson) { lesson in
            LessonDetailView(
                lesson: lesson,
                allLessons: allLessons
            )
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
    
    @ViewBuilder
    private var navigationView: some View {
        if viewModel.canGoBack || viewModel.canGoNext {
            HStack(spacing: 16) {
                if viewModel.canGoBack {
                    LessonNavigationButton(
                        title: "Предыдущий",
                        systemImage: "chevron.left",
                        iconLeading: true,
                        action: { selectedLesson = viewModel.showPreviousLesson() }
                    )
                }
                
                Spacer(minLength: 8)
                
                if viewModel.canGoNext {
                    LessonNavigationButton(
                        title: "Следующий",
                        systemImage: "chevron.right",
                        iconLeading: false,
                        action: { selectedLesson = viewModel.showNextLesson() }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Lesson Navigation Button

private struct LessonNavigationButton: View {
    let title: String
    let systemImage: String
    let iconLeading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if iconLeading {
                    Image(systemName: systemImage)
                    label
                } else {
                    label
                    Image(systemName: systemImage)
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var label: some View {
        Text(title)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Preview

#if DEBUG
struct LessonDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LessonDetailView(
                lesson: PreviewData.lesson,
                allLessons: PreviewData.lessons
            )
        }
        .environment(\.dependencies, .preview)
    }
}
#endif
