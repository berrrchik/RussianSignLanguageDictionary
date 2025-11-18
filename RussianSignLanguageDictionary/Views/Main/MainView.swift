import SwiftUI

struct MainView: View {
    // MARK: - Properties
    
    private let signRepository: SignRepositoryProtocol
    private let favoritesRepository: FavoritesRepositoryProtocol
    
    // MARK: - Init
 
    init(
        signRepository: SignRepositoryProtocol = SignRepository(),
        favoritesRepository: FavoritesRepositoryProtocol = FavoritesRepository()
    ) {
        self.signRepository = signRepository
        self.favoritesRepository = favoritesRepository
    }
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            SearchView(signRepository: signRepository)
                .tabItem {
                    Label("Поиск", systemImage: "magnifyingglass")
                }
            
            FavoritesView(
                favoritesRepository: favoritesRepository,
                signRepository: signRepository
            )
            .tabItem {
                Label("Избранное", systemImage: "heart.fill")
            }
            
            CategoriesView(signRepository: signRepository)
                .tabItem {
                    Label("Категории", systemImage: "square.grid.2x2")
                }
        }
        .task {
            await CategoryService.loadCategories(from: signRepository)
        }
    }
}

// MARK: - Preview

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}

