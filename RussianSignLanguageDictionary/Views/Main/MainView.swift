import SwiftUI

struct MainView: View {
    // MARK: - Properties
    
    private let signRepository: SignRepositoryProtocol
    private let videoRepository: VideoRepositoryProtocol
    
    @EnvironmentObject private var favoritesRepository: FavoritesRepository
    
    // MARK: - Init
 
    init(
        signRepository: SignRepositoryProtocol = SignRepository(),
        videoRepository: VideoRepositoryProtocol = VideoRepository()
    ) {
        self.signRepository = signRepository
        self.videoRepository = videoRepository
    }
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            SearchView(
                signRepository: signRepository,
                videoRepository: videoRepository
            )
            .tabItem {
                Label("Поиск", systemImage: "magnifyingglass")
            }
            
            FavoritesView(
                signRepository: signRepository,
                favoritesRepository: favoritesRepository,
                videoRepository: videoRepository
            )
            .tabItem {
                Label("Избранное", systemImage: "heart.fill")
            }
            
            CategoriesView(
                signRepository: signRepository,
                videoRepository: videoRepository
            )
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

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(PreviewData.favoritesRepository)
    }
}
#endif

