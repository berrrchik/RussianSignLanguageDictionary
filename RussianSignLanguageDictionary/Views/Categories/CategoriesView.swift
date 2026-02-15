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
            ZStack {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: "Загрузка категорий...")
                    
                case .loaded:
                    categoriesGrid
                    
                case .error(let message):
                    ErrorView(message: message, skipAction:  {
                        Task {
                            await viewModel.loadCategories()
                        }
                    })
                }
            }
            .navigationTitle("Категории")
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
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        CategoriesView()
            .environment(\.dependencies, .preview)
    }
}
#endif
