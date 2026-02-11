import SwiftUI

struct LessonsView: View {
    @StateObject private var viewModel: LessonsViewModel
    
    private let lessonRepository: LessonRepositoryProtocol
    private let videoRepository: VideoRepositoryProtocol
    
    init(
        lessonRepository: LessonRepositoryProtocol,
        videoRepository: VideoRepositoryProtocol
    ) {
        self.lessonRepository = lessonRepository
        self.videoRepository = videoRepository
        _viewModel = StateObject(wrappedValue: LessonsViewModel(lessonRepository: lessonRepository))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: "Загрузка уроков...")
                case .loaded:
                    lessonsContent
                case .error(let message):
                    ErrorView(message: message)
                }
            }
            .navigationTitle("Обучение")
            .task {
                await viewModel.loadLessons()
            }
            .refreshable {
                await viewModel.loadLessons()
            }
        }
    }

    // MARK: - Subviews
    
    private var lessonsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerView
                lessonsList
            }
        }
    }
    
    private var headerView: some View {
        Text("Обучающие видеоматериалы по русскому жестовому языку «Давайте знакомиться!»")
            .font(.headline)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.top, 8)
    }

    private var lessonsList: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.lessons) { lesson in
                NavigationLink(destination: LessonDetailView(
                    lesson: lesson,
                    allLessons: viewModel.lessons,
                    videoRepository: videoRepository
                )) {
                    lessonRow(lesson)
                }
            }
        }
    }
    
    private func lessonRow(_ lesson: Lesson) -> some View {
        HStack {
            Text(lesson.title)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

#if DEBUG
struct LessonsView_Previews: PreviewProvider {
    static var previews: some View {
        LessonsView(
            lessonRepository: PreviewData.lessonRepository,
            videoRepository: PreviewData.videoRepository
        )
    }
}
#endif
