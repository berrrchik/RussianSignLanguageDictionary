import SwiftUI

struct SignDetailView: View {
    @StateObject private var viewModel: SignDetailViewModel
    
    // MARK: - Init
    
    init(sign: Sign, visitedSignIds: Set<String> = []) {
        _viewModel = StateObject(wrappedValue: SignDetailViewModel(
            sign: sign,
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
        .navigationBackButton()
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
            favoriteOfflineBadge
            
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
            Text(viewModel.categoryName)
                .font(.subheadline)
        }
        .padding(.horizontal, LayoutConstants.SignDetail.categoryBadgeHorizontalPadding)
        .padding(.vertical, LayoutConstants.SignDetail.categoryBadgeVerticalPadding)
        .background(Color.accentColor.opacity(LayoutConstants.Opacity.accent))
        .cornerRadius(LayoutConstants.SignDetail.badgeCornerRadius)
    }

    @ViewBuilder
    private var favoriteOfflineBadge: some View {
        if viewModel.isFavorite, let status = viewModel.favoriteOfflineStatus {
            HStack(spacing: 6) {
                Image(systemName: favoriteStatusIcon(for: status))
                    .font(.caption)
                Text(status.displayText)
                    .font(.caption)
            }
            .foregroundColor(favoriteStatusColor(for: status))
            .padding(.horizontal, LayoutConstants.SignDetail.categoryBadgeHorizontalPadding)
            .padding(.vertical, LayoutConstants.SignDetail.categoryBadgeVerticalPadding)
            .background(favoriteStatusColor(for: status).opacity(0.12))
            .cornerRadius(LayoutConstants.SignDetail.badgeCornerRadius)
        }
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
        async let videoLoad: Void = viewModel.loadVideo()
        async let categoryLoad: Void = viewModel.loadCategoryName()
        viewModel.checkFavoriteStatus()
        _ = await (videoLoad, categoryLoad)
    }

    private func favoriteStatusColor(for status: FavoriteOfflineStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .readyOffline:
            return .green
        case .failed:
            return .red
        }
    }

    private func favoriteStatusIcon(for status: FavoriteOfflineStatus) -> String {
        switch status {
        case .pending:
            return "arrow.triangle.2.circlepath"
        case .readyOffline:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SignDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Превью с синонимами
            NavigationStack {
                SignDetailView(sign: PreviewData.signWithSynonyms)
            }
            .previewDisplayName("С синонимами")
            
            // Превью без синонимов (по умолчанию)
            NavigationStack {
                SignDetailView(sign: PreviewData.sign)
            }
            .previewDisplayName("Без синонимов")
            
            // Превью с множеством видео
            NavigationStack {
                SignDetailView(sign: PreviewData.signWithMultipleVideos)
            }
            .previewDisplayName("С несколькими видео")
            
            // Превью с длинным описанием
            NavigationStack {
                SignDetailView(sign: PreviewData.signWithLongDescription)
            }
            .previewDisplayName("Длинное описание")
        }
        .environment(\.dependencies, .preview)
    }
}
#endif
