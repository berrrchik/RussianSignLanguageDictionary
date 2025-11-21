import SwiftUI

struct SignDetailView: View {
    @StateObject private var viewModel: SignDetailViewModel
    
    // MARK: - Init
    
    init(
        sign: Sign,
        videoRepository: VideoRepositoryProtocol,
        favoritesRepository: FavoritesRepositoryProtocol
    ) {
        _viewModel = StateObject(wrappedValue: SignDetailViewModel(
            sign: sign,
            videoRepository: videoRepository,
            favoritesRepository: favoritesRepository
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
    }
    
    // MARK: - Subviews
    
    private var videoSection: some View {
        Group {
            if viewModel.isLoadingVideo {
                LoadingView(message: "Загрузка видео...")
            } else if let errorMessage = viewModel.videoErrorMessage {
                ErrorView(message: errorMessage) {
                    Task { await viewModel.loadVideo() }
                }
            } else if let videoURL = viewModel.videoURL {
                VideoPlayerView(videoURL: videoURL)
            }
        }
        .frame(height: LayoutConstants.VideoPlayer.defaultHeight)
    }
    
    private var signInformationSection: some View {
        VStack(alignment: .leading, spacing: LayoutConstants.SignDetail.elementSpacing) {
            signHeader
            categoryBadge
            if !viewModel.sign.keywords.isEmpty {
                keywordsSection
            }
        }
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
            Text(CategoryService.name(for: viewModel.sign.category))
                .font(.subheadline)
        }
        .padding(.horizontal, LayoutConstants.SignDetail.categoryBadgeHorizontalPadding)
        .padding(.vertical, LayoutConstants.SignDetail.categoryBadgeVerticalPadding)
        .background(Color.accentColor.opacity(LayoutConstants.Opacity.accent))
        .cornerRadius(LayoutConstants.SignDetail.badgeCornerRadius)
    }
    
    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("")
                .font(.headline)
            
            FlowLayout(spacing: LayoutConstants.SignDetail.keywordSpacing) {
                ForEach(viewModel.sign.keywords, id: \.self) { keyword in
                    keywordBadge(keyword)
                }
            }
        }
    }
    
    private func keywordBadge(_ keyword: String) -> some View {
        Text("")
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

// MARK: - FlowLayout Helper

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        GeometryReader { _ in
            self.generateContent()
        }
    }
    
    private func generateContent() -> some View {
        return ZStack(alignment: .topLeading) {
            content().fixedSize()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Preview

#if DEBUG
struct SignDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SignDetailView(
                sign: PreviewData.sign,
                videoRepository: PreviewData.videoRepository,
                favoritesRepository: PreviewData.favoritesRepository
            )
        }
    }
}
#endif

