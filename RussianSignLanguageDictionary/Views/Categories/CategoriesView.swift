import SwiftUI

struct CategoriesView: View {
    @StateObject private var viewModel: CategoriesViewModel
    
    private let columns: [GridItem] = [
        GridItem(
            .adaptive(
                minimum: LayoutConstants.CategoryCard.gridMinWidth,
                maximum: LayoutConstants.CategoryCard.gridMaxWidth
            ),
            spacing: LayoutConstants.CategoryCard.gridSpacing
        )
    ]
    
    init(signRepository: SignRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: CategoriesViewModel(signRepository: signRepository))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingView(message: "Загрузка категорий...")
                    
                case .loaded:
                    categoriesGrid
                    
                case .error(let message):
                    ErrorView(message: message) {
                        Task {
                            await viewModel.loadCategories()
                        }
                    }
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

struct CategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        CategoriesView(signRepository: MockSignRepository())
    }
}

// MARK: - Mock

private class MockSignRepository: SignRepositoryProtocol {
    func loadAllSigns() async throws -> [Sign] { [] }
    
    func loadCategories() async throws -> [Category] {
        [
            Category(id: "alphabet", name: "Алфавит", order: 1, signCount: 33, icon: "textformat.abc", color: nil),
            Category(id: "animals", name: "Животные", order: 2, signCount: 69, icon: "pawprint.fill", color: nil)
        ]
    }
    
    func getSign(byId id: String) async throws -> Sign? { nil }
    func getSigns(byCategory categoryId: String) async throws -> [Sign] { [] }
    func searchSigns(query: String) async throws -> [Sign] { [] }
}

