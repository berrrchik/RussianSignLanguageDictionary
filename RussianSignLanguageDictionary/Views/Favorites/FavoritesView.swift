import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    @Environment(\.dependencies) private var deps
    @State private var showClearConfirmation = false
    @State private var selectedSign: Sign?
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Избранное")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        OfflineStatusToolbarItem()
                    }

                    if !viewModel.favoriteSigns.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showClearConfirmation = true
                            } label: {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                            }
                            .accessibilityLabel("Очистить все избранное")
                        }
                    }
                }
                .confirmationDialog(
                    "Удалить все избранные жесты?",
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Удалить всё", role: .destructive) {
                        viewModel.clearAllFavorites()
                    }
                    Button("Отмена", role: .cancel) { }
                } message: {
                    Text("Это действие нельзя отменить. Скачанные видео также будут удалены.")
                }
                .navigationDestination(item: $selectedSign) { sign in
                    SignDetailView(sign: sign)
                }
                .onAppear {
                    AnalyticsService.logScreenView(screenName: "favorites", screenClass: "FavoritesView")
                }
                .task {
                    await viewModel.loadFavorites()
                }
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.favoriteSigns.isEmpty {
            LoadingView(message: "Загрузка избранного...")
        } else if let errorMessage = viewModel.errorMessage, viewModel.favoriteSigns.isEmpty {
            ErrorView(message: errorMessage, retryAction: {
                Task {
                    await viewModel.loadFavorites()
                }
            })
        } else if viewModel.favoriteSigns.isEmpty {
            emptyStateView
        } else {
            favoritesListView
        }
    }
    
    // MARK: - Subviews
    
    private var favoritesListView: some View {
        AlphabeticScrollbarTableView(
            sections: viewModel.groupedFavorites,
            favoritesRepository: deps.favoritesRepository,
            categoryNamesById: viewModel.categoryNamesById,
            favoriteOfflineStatusProvider: { signId in
                viewModel.offlineStatus(for: signId)
            },
            onSignSelected: { sign in
                selectedSign = sign
            }
        )
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
    @MainActor
    static var previews: some View {
        FavoritesView()
            .environment(\.dependencies, .preview)
            .environmentObject(AppStatusViewModel(
                signRepository: PreviewData.signRepository,
                networkMonitor: PreviewData.networkMonitor
            ))
    }
}
#endif
