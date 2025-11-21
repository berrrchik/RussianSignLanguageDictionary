import SwiftUI

struct CategoryDetailView: View {
    @ObservedObject private var viewModel: CategoryDetailViewModel
    @EnvironmentObject private var favoritesRepository: FavoritesRepository
    
    private let videoRepository: VideoRepositoryProtocol
    
    init(
        viewModel: CategoryDetailViewModel,
        videoRepository: VideoRepositoryProtocol
    ) {
        self.viewModel = viewModel
        self.videoRepository = videoRepository
    }
    
    var body: some View {
        ZStack {
            switch viewModel.state {
            case .idle, .loading:
                LoadingView(message: "Загрузка жестов...")
                
            case .loaded:
                if viewModel.signs.isEmpty {
                    EmptyStateView(
                        icon: "tray.fill",
                        title: "Жесты не найдены",
                        message: "В этой категории пока нет жестов"
                    )
                } else {
                    signsList
                }
                
            case .error(let message):
                ErrorView(message: message) {
                    Task {
                        await viewModel.loadSigns()
                    }
                }
            }
        }
        .navigationTitle(viewModel.category.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel.signs.isEmpty {
                await viewModel.loadSigns()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var signsList: some View {
        List {
            Section {
                ForEach(viewModel.signs) { sign in
                    NavigationLink(destination: SignDetailView(
                        sign: sign,
                        videoRepository: videoRepository,
                        favoritesRepository: favoritesRepository
                    )) {
                        SignRowView(
                            sign: sign,
                            showFavoriteIndicator: true,
                            isFavorite: favoritesRepository.isFavorite(signId: sign.id)
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct CategoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = CategoryDetailViewModel(
            category: PreviewData.category,
            signRepository: PreviewData.signRepository
        )
        
        NavigationStack {
            CategoryDetailView(
                viewModel: viewModel,
                videoRepository: PreviewData.videoRepository
            )
            .environmentObject(PreviewData.favoritesRepository)
        }
    }
}
#endif

