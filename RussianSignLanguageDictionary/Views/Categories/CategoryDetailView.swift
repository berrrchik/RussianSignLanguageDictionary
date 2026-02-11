import SwiftUI

struct CategoryDetailView: View {
    @StateObject private var viewModel: CategoryDetailViewModel
    @State private var selectedSign: Sign?
    
    private let signRepository: SignRepositoryProtocol
    private let videoRepository: VideoRepositoryProtocol
    private let favoritesRepository: FavoritesRepositoryProtocol
    private let categoryService: CategoryServiceProtocol
    
    init(
        category: Category,
        signRepository: SignRepositoryProtocol,
        videoRepository: VideoRepositoryProtocol,
        favoritesRepository: FavoritesRepositoryProtocol,
        categoryService: CategoryServiceProtocol
    ) {
        self.signRepository = signRepository
        self.videoRepository = videoRepository
        self.favoritesRepository = favoritesRepository
        self.categoryService = categoryService
        _viewModel = StateObject(wrappedValue: CategoryDetailViewModel(
            category: category,
            signRepository: signRepository
        ))
    }
    
    var body: some View {
        contentView
            .navigationTitle(viewModel.category.name)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedSign) { sign in
                SignDetailView(
                    sign: sign,
                    dependencies: .init(
                        signRepository: signRepository,
                        videoRepository: videoRepository,
                        favoritesRepository: favoritesRepository,
                        categoryService: categoryService
                    )
                )
            }
            .task {
                if viewModel.signs.isEmpty {
                    await viewModel.loadSigns()
                }
            }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
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
                ErrorView(message: message, skipAction:  {
                    Task {
                        await viewModel.loadSigns()
                    }
                })
            }
        }
    }
    
    // MARK: - Subviews
    
    private var signsList: some View {
        AlphabeticScrollbarTableView(
            sections: viewModel.groupedSigns,
            signRepository: signRepository,
            videoRepository: videoRepository,
            favoritesRepository: favoritesRepository,
            getCategoryName: { [categoryService] categoryId in
                categoryService.name(for: categoryId)
            },
            onSignSelected: { sign in
                selectedSign = sign
            }
        )
    }
}

// MARK: - Preview

#if DEBUG
struct CategoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CategoryDetailView(
                category: PreviewData.category,
                signRepository: PreviewData.signRepository,
                videoRepository: PreviewData.videoRepository,
                favoritesRepository: PreviewData.favoritesRepository,
                categoryService: PreviewData.categoryService
            )
        }
    }
}
#endif
