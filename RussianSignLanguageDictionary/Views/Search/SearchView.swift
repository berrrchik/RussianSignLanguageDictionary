import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @EnvironmentObject private var favoritesRepository: FavoritesRepository
    
    private let videoRepository: VideoRepositoryProtocol
    
    init(
        signRepository: SignRepositoryProtocol,
        videoRepository: VideoRepositoryProtocol
    ) {
        self.videoRepository = videoRepository
        _viewModel = StateObject(wrappedValue: SearchViewModel(signRepository: signRepository))
    }
    
    var body: some View {
        NavigationStack {
            contentView
            .navigationTitle("Поиск")
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Введите слово для поиска"
            )
            .task {
                await viewModel.loadAllSigns()
            }
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            if viewModel.isLoading {
                LoadingView(message: loadingMessage)
            } else if let errorMessage = viewModel.errorMessage {
                ErrorView(message: errorMessage, retryAction: retryLoading)
            } else if viewModel.searchResults.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: emptyStateTitle,
                    message: emptyStateMessage
                )
            } else {
                searchResultsList
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var loadingMessage: String {
        viewModel.searchQuery.isEmpty ? "Загрузка жестов..." : "Поиск..."
    }
    
    private var emptyStateTitle: String {
        viewModel.searchQuery.isEmpty ? "Нет данных" : "Ничего не найдено"
    }
    
    private var emptyStateMessage: String {
        viewModel.searchQuery.isEmpty ? "Данные о жестах не загружены" : "Попробуйте изменить запрос"
    }
    
    // MARK: - Actions
    
    private func retryLoading() {
        Task {
            await viewModel.loadAllSigns()
        }
    }
    
    // MARK: - Subviews
    
    private var searchResultsList: some View {
        List {
            Section {
                ForEach(viewModel.searchResults) { sign in
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
struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(
            signRepository: PreviewData.signRepository,
            videoRepository: PreviewData.videoRepository
        )
        .environmentObject(PreviewData.favoritesRepository)
    }
}
#endif

