import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel: FavoritesViewModel
    @State private var showClearAlert = false
    
    init(favoritesRepository: FavoritesRepositoryProtocol, signRepository: SignRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: FavoritesViewModel(
            favoritesRepository: favoritesRepository,
            signRepository: signRepository
        ))
    }
    
    init() {
        let favoritesRepo = FavoritesRepository()
        let signRepo = SignRepository()
        _viewModel = StateObject(wrappedValue: FavoritesViewModel(
            favoritesRepository: favoritesRepo,
            signRepository: signRepo
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
        List {
            Section {
                ForEach(viewModel.favoriteSigns) { sign in
                    NavigationLink(destination: SignDetailView(sign: sign)) {
                        SignRowView(sign: sign, showFavoriteIndicator: false)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.removeFavorite(signId: sign.id)
                        } label: {
                            Label("Удалить", systemImage: "trash.fill")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
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

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoritesView()
    }
}

