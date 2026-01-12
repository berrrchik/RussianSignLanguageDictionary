import SwiftUI

struct CategoryDetailView: View {
    @ObservedObject private var viewModel: CategoryDetailViewModel
    @EnvironmentObject private var favoritesRepository: FavoritesRepository
    @State private var selectedSign: Sign?
    
    private let signRepository: SignRepositoryProtocol
    private let videoRepository: VideoRepositoryProtocol
    
    init(
        viewModel: CategoryDetailViewModel,
        signRepository: SignRepositoryProtocol,
        videoRepository: VideoRepositoryProtocol
    ) {
        self.viewModel = viewModel
        self.signRepository = signRepository
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
        .navigationDestination(item: $selectedSign) { sign in
            SignDetailView(
                sign: sign,
                signRepository: signRepository,
                videoRepository: videoRepository,
                favoritesRepository: favoritesRepository
            )
        }
        .task {
            if viewModel.signs.isEmpty {
                await viewModel.loadSigns()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var signsList: some View {
        AlphabeticScrollbarTableView(
            sections: groupedSigns,
            signRepository: signRepository,
            videoRepository: videoRepository,
            favoritesRepository: favoritesRepository,
            getCategoryName: { categoryId in
                CategoryService.name(for: categoryId)
            },
            onSignSelected: { sign in
                selectedSign = sign
            }
        )
    }
    
    // MARK: - Computed Properties
    
    private var groupedSigns: [SearchViewModel.SignSection] {
        SignGroupingHelper.groupByFirstLetter(viewModel.signs)
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
                signRepository: PreviewData.signRepository,
                videoRepository: PreviewData.videoRepository
            )
            .environmentObject(PreviewData.favoritesRepository)
        }
    }
}
#endif

