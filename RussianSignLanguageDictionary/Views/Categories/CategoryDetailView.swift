import SwiftUI

struct CategoryDetailView: View {
    @StateObject private var viewModel: CategoryDetailViewModel
    @Environment(\.dependencies) private var deps
    @State private var selectedSign: Sign?
    
    init(category: Category) {
        _viewModel = StateObject(wrappedValue: CategoryDetailViewModel(category: category))
    }
    
    var body: some View {
        contentView
            .navigationTitle(viewModel.category.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBackButton()
            .onAppear {
                AnalyticsService.logCategoryOpened(
                    categoryId: viewModel.category.id,
                    categoryName: viewModel.category.name
                )
            }
            .navigationDestination(item: $selectedSign) { sign in
                SignDetailView(sign: sign)
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
        LoadableContentView(state: viewModel.state, loadingMessage: "Загрузка жестов...") {
            if viewModel.signs.isEmpty {
                EmptyStateView(
                    icon: "tray.fill",
                    title: "Жесты не найдены",
                    message: "В этой категории пока нет жестов"
                )
            } else {
                signsList
            }
        } errorView: { message in
            ErrorView(message: message, skipAction: {
                Task {
                    await viewModel.loadSigns()
                }
            })
        }
    }
    
    // MARK: - Subviews
    
    private var signsList: some View {
        AlphabeticScrollbarTableView(
            sections: viewModel.groupedSigns,
            favoritesRepository: deps.favoritesRepository,
            categoryNamesById: viewModel.categoryNamesById,
            favoriteOfflineStatusProvider: nil,
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
            CategoryDetailView(category: PreviewData.category)
        }
        .environment(\.dependencies, .preview)
    }
}
#endif
