import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel: FavoritesViewModel
    @State private var showClearAlert = false
    @State private var selectedSign: Sign?
    
    private let signRepository: SignRepositoryProtocol
    private let videoRepository: VideoRepositoryProtocol
    
    init(
        signRepository: SignRepositoryProtocol,
        favoritesRepository: FavoritesRepositoryProtocol,
        videoRepository: VideoRepositoryProtocol
    ) {
        self.signRepository = signRepository
        self.videoRepository = videoRepository
        _viewModel = StateObject(wrappedValue: FavoritesViewModel(
            favoritesRepository: favoritesRepository,
            signRepository: signRepository
        ))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    LoadingView(message: "Загрузка избранного...")
                } else if viewModel.favoriteSigns.isEmpty {
                    emptyStateView
                } else {
                    favoritesListView
                }
            }
            .navigationTitle("Избранное")
            .toolbar {
                if !viewModel.favoriteSigns.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showClearAlert = true
                        } label: {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                        }
                        .accessibilityLabel("Очистить все избранное")
                    }
                }
            }
            .alert("Очистить избранное?", isPresented: $showClearAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Очистить", role: .destructive) {
                    viewModel.clearAllFavorites()
                }
            } message: {
                Text("Все избранные жесты будут удалены. Это действие нельзя отменить.")
            }
            .navigationDestination(item: $selectedSign) { sign in
                SignDetailView(
                    sign: sign,
                    signRepository: signRepository,
                    videoRepository: videoRepository,
                    favoritesRepository: viewModel.favoritesRepository
                )
            }
            .overlay(alignment: .bottom) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, LayoutConstants.Toast.horizontalPadding)
                        .padding(.vertical, LayoutConstants.Toast.verticalPadding)
                        .background(Color.orange)
                        .cornerRadius(LayoutConstants.Toast.cornerRadius)
                        .padding(.bottom, LayoutConstants.Toast.bottomPadding)
                }
            }
        }
        .task {
            await viewModel.loadFavorites()
        }
    }
    
    // MARK: - Subviews
    
    private var favoritesListView: some View {
        AlphabeticScrollbarTableView(
            sections: groupedFavorites,
            signRepository: signRepository,
            videoRepository: videoRepository,
            favoritesRepository: viewModel.favoritesRepository,
            getCategoryName: { categoryId in
                CategoryService.name(for: categoryId)
            },
            onSignSelected: { sign in
                selectedSign = sign
            }
        )
    }
    
    // MARK: - Computed Properties
    
    private var groupedFavorites: [SearchViewModel.SignSection] {
        SignGroupingHelper.groupByFirstLetter(viewModel.favoriteSigns)
    }
    
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "heart",
            title: "У вас пока нет избранных жестов",
            message: "Добавьте жесты в избранное для быстрого доступа",
            hint: "Нажмите ❤️ на любом жесте"
        )
    }
}

// MARK: - Preview

#if DEBUG
struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FavoritesView(
                signRepository: PreviewData.signRepository,
                favoritesRepository: PreviewData.favoritesRepository,
                videoRepository: PreviewData.videoRepository
            )
        }
    }
}
#endif

