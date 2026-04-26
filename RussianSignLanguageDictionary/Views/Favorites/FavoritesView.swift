import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    @Environment(\.dependencies) private var deps
    @State private var showClearAlert = false
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
                    SignDetailView(sign: sign)
                }
                .overlay(alignment: .bottom) {
                    if let errorMessage = viewModel.errorMessage, !viewModel.favoriteSigns.isEmpty {
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
        ZStack {
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
