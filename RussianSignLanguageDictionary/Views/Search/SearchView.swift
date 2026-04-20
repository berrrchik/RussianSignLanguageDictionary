import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @Environment(\.dependencies) private var deps
    @State private var selectedSign: Sign?
    
    var body: some View {
        NavigationStack {
            contentView
            .navigationTitle("Поиск")
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Введите слово для поиска"
            )
            .onAppear {
                AnalyticsService.logScreenView(screenName: "search", screenClass: "SearchView")
            }
            .task(id: "initialLoad") {
                await viewModel.loadAllSigns()
            }
            .navigationDestination(item: $selectedSign) { sign in
                SignDetailView(sign: sign)
            }
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            if !viewModel.isLoading && viewModel.errorMessage == nil {
                HStack {
                    categoryFilterButton
                    
                    Spacer()
                    
                    sortButton
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            
            ZStack {
                if viewModel.isLoading {
                    LoadingView(message: loadingMessage)
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage, retryAction: retryLoading)
                } else if viewModel.searchResults.isEmpty {
                    if viewModel.isReady {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: emptyStateTitle,
                            message: emptyStateMessage
                        )
                    }
                } else {
                    searchResultsList
                }
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
        AlphabeticScrollbarTableView(
            sections: viewModel.groupedResults,
            favoritesRepository: deps.favoritesRepository,
            categoryNamesById: viewModel.categoryNamesById,
            onSignSelected: { sign in
                selectedSign = sign
            }
        )
    }
    
    // MARK: - Filter and Sort Buttons
    
    private var categoryFilterButton: some View {
        Menu {
            Button(action: {
                viewModel.selectedCategoryId = nil
            }) {
                HStack {
                    Text("Все категории")
                    if viewModel.selectedCategoryId == nil {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            ForEach(viewModel.categories) { category in
                Button(action: {
                    viewModel.selectedCategoryId = category.id
                }) {
                    HStack {
                        Text(category.name)
                        if viewModel.selectedCategoryId == category.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(selectedCategoryName)
                    .font(.system(size: 15, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    private var selectedCategoryName: String {
        guard let categoryId = viewModel.selectedCategoryId,
              let category = viewModel.categories.first(where: { $0.id == categoryId }) else {
            return "Все категории"
        }
        return category.name
    }
    
    private var sortButton: some View {
        Button(action: {
            viewModel.sortOrder = viewModel.sortOrder == .ascending ? .descending : .ascending
        }) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 36, height: 36)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
        }
        .accessibilityLabel(viewModel.sortOrder == .ascending ? "Сортировка: А-Я" : "Сортировка: Я-А")
        .accessibilityHint("Нажмите для изменения порядка сортировки")
    }
}

// MARK: - Preview

#if DEBUG
struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
            .environment(\.dependencies, .preview)
    }
}
#endif
