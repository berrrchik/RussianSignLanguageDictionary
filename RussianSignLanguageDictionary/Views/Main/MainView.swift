import SwiftUI

struct MainView: View {
    // MARK: - Properties
    
    private let signRepository: SignRepositoryProtocol
    private let videoRepository: VideoRepositoryProtocol
    
    @EnvironmentObject private var favoritesRepository: FavoritesRepository
    @StateObject private var syncViewModel: SyncViewModel
    
    // MARK: - Init
 
    init(
        signRepository: SignRepositoryProtocol? = nil,
        videoRepository: VideoRepositoryProtocol = VideoRepository(),
        syncRepository: SyncRepositoryProtocol? = nil,
        cacheService: CacheService? = nil
    ) {
        // Создаем сервисы синхронизации, если не переданы
        let syncRepo = syncRepository ?? SyncRepository()
        let cache = cacheService ?? CacheService()
        
        // Создаем SignRepository с синхронизацией
        let signRepo = signRepository ?? SignRepository(
            syncRepository: syncRepo,
            cacheService: cache
        )
        
        self.signRepository = signRepo
        self.videoRepository = videoRepository
        
        // Создаем SyncViewModel
        self._syncViewModel = StateObject(
            wrappedValue: SyncViewModel(
                syncRepository: syncRepo,
                cacheService: cache
            )
        )
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
            // Загружаем категории
            await CategoryService.loadCategories(from: signRepository)
            
            // Выполняем синхронизацию при запуске
            await syncViewModel.sync()
        }
        .overlay {
            // Показываем индикатор загрузки во время синхронизации
            if syncViewModel.isSyncing {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Синхронизация...")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
            }
        }
        .alert("Ошибка синхронизации", isPresented: .constant(syncViewModel.syncError != nil)) {
            Button("OK") {
                syncViewModel.clearError()
            }
        } message: {
            if let error = syncViewModel.syncError {
                Text(error)
            }
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

