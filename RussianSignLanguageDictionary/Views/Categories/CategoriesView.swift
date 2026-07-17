import SwiftUI

struct CategoriesView: View {
    @StateObject private var viewModel = CategoriesViewModel()
    @Environment(\.dependencies) private var deps
    
    private let columns: [GridItem] = [
        GridItem(
            .adaptive(
                minimum: LayoutConstants.CategoryCard.gridMinWidth,
                maximum: LayoutConstants.CategoryCard.gridMaxWidth
            ),
            spacing: LayoutConstants.CategoryCard.gridSpacing
        )
    ]
    
    var body: some View {
        NavigationStack {
            LoadableContentView(state: viewModel.state, loadingMessage: "Загрузка категорий...") {
                categoriesGrid
            } errorView: { message in
                ErrorView(message: message, skipAction: {
                    Task {
                        await viewModel.loadCategories()
                    }
                })
            }
            .navigationTitle("Категории")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    OfflineStatusToolbarItem()
                }
            }
            .onAppear {
                AnalyticsService.logScreenView(screenName: "categories", screenClass: "CategoriesView")
            }
            .task {
                if viewModel.categories.isEmpty {
                    await viewModel.loadCategories()
                }
            }
            .refreshable {
                await viewModel.refreshCategories()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var categoriesGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: LayoutConstants.CategoryCard.gridSpacing) {
                ForEach(viewModel.categories) { category in
                    NavigationLink(destination: CategoryDetailView(category: category)) {
                        CategoryCardView(category: category)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(category.name)
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CategoriesView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        CategoriesView()
            .environment(\.dependencies, .preview)
            .environmentObject(AppStatusViewModel(
                signRepository: PreviewData.signRepository,
                networkMonitor: PreviewData.networkMonitor
            ))
    }
}
#endif
