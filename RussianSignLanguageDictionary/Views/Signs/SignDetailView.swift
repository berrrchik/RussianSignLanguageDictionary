import SwiftUI

struct SignDetailView: View {
    @StateObject private var viewModel: SignDetailViewModel
    
    // MARK: - Dependencies
    
    /// Группа зависимостей для SignDetailView
    /// Уменьшает количество параметров в init и упрощает передачу зависимостей по цепочке
    struct Dependencies {
        let signRepository: SignRepositoryProtocol
        let videoRepository: VideoRepositoryProtocol
        let favoritesRepository: FavoritesRepositoryProtocol
        let categoryService: CategoryServiceProtocol
    }
    
    private let dependencies: Dependencies
    
    // MARK: - Init
    
    init(
        sign: Sign,
        dependencies: Dependencies,
        visitedSignIds: Set<String> = []
    ) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: SignDetailViewModel(
            sign: sign,
            signRepository: dependencies.signRepository,
            videoRepository: dependencies.videoRepository,
            favoritesRepository: dependencies.favoritesRepository,
            visitedSignIds: visitedSignIds
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: LayoutConstants.SignDetail.sectionSpacing) {
                videoSection
                signInformationSection
            }
        }
        .navigationTitle(viewModel.sign.word)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task { await loadData() }
        .onChange(of: viewModel.currentVideoIndex) { _ in
            Task { await viewModel.loadVideo() }
        }
        .onDisappear {
            viewModel.cleanupVideo()
        }
        .navigationDestination(item: $viewModel.selectedSynonymSign) { sign in
            SignDetailView(
                sign: sign,
                dependencies: dependencies,
                visitedSignIds: viewModel.visitedSignIds
            )
        }
    }
    
    // MARK: - Subviews
    
    private var videoSection: some View {
        VStack(spacing: LayoutConstants.SignDetail.sectionSpacing) {
            if viewModel.isLoadingVideo {
                LoadingView(message: "Загрузка видео...")
                    .frame(height: LayoutConstants.VideoPlayer.defaultHeight)
            } else if let errorMessage = viewModel.videoErrorMessage {
                ErrorView(
                    message: errorMessage,
                    retryAction: { Task { await viewModel.loadVideo() } },
                    skipAction: viewModel.canGoNext ? { viewModel.showNextVideo() } : nil
                )
                .frame(height: LayoutConstants.VideoPlayer.defaultHeight)
            } else if let videoURL = viewModel.videoURL {
                VideoPlayerView(videoURL: videoURL)
                    .frame(height: LayoutConstants.VideoPlayer.defaultHeight)
                    .animation(.easeInOut, value: viewModel.currentVideoIndex)
            }
            
            if let videos = viewModel.sign.videos, videos.count > 1 {
                VideoNavigationView(
                    currentIndex: viewModel.currentVideoIndex,
                    totalCount: videos.count,
                    canGoBack: viewModel.canGoBack,
                    canGoNext: viewModel.canGoNext,
                    onPrevious: { viewModel.showPreviousVideo() },
                    onNext: { viewModel.showNextVideo() }
                )
            }
            
            if let description = viewModel.currentContextDescription {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }
    
    private var signInformationSection: some View {
        VStack(alignment: .leading, spacing: LayoutConstants.SignDetail.elementSpacing) {
            signHeader
            categoryBadge
            
            if let synonyms = viewModel.sign.synonyms, !synonyms.isEmpty {
                if viewModel.isLoadingSynonym {
                    LoadingView(message: "Загрузка синонима...", size: .small)
                        .frame(height: 40)
                } else if let error = viewModel.synonymError {
                    VStack(spacing: 8) {
                        ErrorView(
                            message: error,
                            retryAction: {
                                viewModel.retrySynonymLoad()
                            }
                        )
                        .frame(height: 100)
                        
                        SynonymListView(
                            synonyms: synonyms,
                            currentSignId: viewModel.sign.id,
                            visitedSignIds: viewModel.visitedSignIds,
                            onSynonymTap: { synonymId in
                                viewModel.navigateToSign(synonymId)
                            }
                        )
                    }
                } else {
                    SynonymListView(
                        synonyms: synonyms,
                        currentSignId: viewModel.sign.id,
                        visitedSignIds: viewModel.visitedSignIds,
                        onSynonymTap: { synonymId in
                            viewModel.navigateToSign(synonymId)
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
    
    private var signHeader: some View {
        VStack(alignment: .leading, spacing: LayoutConstants.SignDetail.elementSpacing) {
            if !viewModel.sign.description.isEmpty {
                Text(viewModel.sign.description)
                    .font(.title2)
            }
        }
    }
    
    private var categoryBadge: some View {
        HStack {
            Image(systemName: "folder.fill")
                .font(.caption)
            Text(dependencies.categoryService.name(for: viewModel.sign.categoryId))
                .font(.subheadline)
        }
        .padding(.horizontal, LayoutConstants.SignDetail.categoryBadgeHorizontalPadding)
        .padding(.vertical, LayoutConstants.SignDetail.categoryBadgeVerticalPadding)
        .background(Color.accentColor.opacity(LayoutConstants.Opacity.accent))
        .cornerRadius(LayoutConstants.SignDetail.badgeCornerRadius)
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                viewModel.toggleFavorite()
            } label: {
                Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(viewModel.isFavorite ? .red : .primary)
            }
            .accessibilityLabel(viewModel.isFavorite ? "Удалить из избранного" : "Добавить в избранное")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadData() async {
        await viewModel.loadVideo()
        viewModel.checkFavoriteStatus()
    }
}

// MARK: - Preview

#if DEBUG
struct SignDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Превью с синонимами
            NavigationStack {
                SignDetailView(
                    sign: PreviewData.signWithSynonyms,
                    dependencies: PreviewData.signDetailDependencies
                )
            }
            .previewDisplayName("С синонимами")
            
            // Превью без синонимов (по умолчанию)
            NavigationStack {
                SignDetailView(
                    sign: PreviewData.sign,
                    dependencies: PreviewData.signDetailDependencies
                )
            }
            .previewDisplayName("Без синонимов")
            
            // Превью с множеством видео
            NavigationStack {
                SignDetailView(
                    sign: PreviewData.signWithMultipleVideos,
                    dependencies: PreviewData.signDetailDependencies
                )
            }
            .previewDisplayName("С несколькими видео")
            
            // Превью с длинным описанием
            NavigationStack {
                SignDetailView(
                    sign: PreviewData.signWithLongDescription,
                    dependencies: PreviewData.signDetailDependencies
                )
            }
            .previewDisplayName("Длинное описание")
        }
    }
}
#endif

