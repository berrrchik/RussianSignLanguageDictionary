import SwiftUI

struct MainView: View {
    // MARK: - Properties
    
    private let signRepository: SignRepositoryProtocol
    private let videoRepository: VideoRepositoryProtocol
    private let lessonRepository: LessonRepositoryProtocol
    private let categoryService: CategoryServiceProtocol
    private let favoritesRepository: FavoritesRepositoryProtocol
    private let networkMonitor: NetworkMonitorProtocol
    
    @StateObject private var syncViewModel: SyncViewModel
    @StateObject private var searchViewModel: SearchViewModel
    @State private var isInitialized = false
    @State private var showSyncError = false
        
    // MARK: - Init
    
    init(container: DIContainer = .shared) {
        self.signRepository = container.resolve(SignRepositoryProtocol.self)
        self.videoRepository = container.resolve(VideoRepositoryProtocol.self)
        self.lessonRepository = container.resolve(LessonRepositoryProtocol.self)
        self.categoryService = container.resolve(CategoryServiceProtocol.self)
        self.favoritesRepository = container.resolve(FavoritesRepositoryProtocol.self)
        self.networkMonitor = container.resolve(NetworkMonitorProtocol.self)
        
        self._syncViewModel = StateObject(
            wrappedValue: SyncViewModel(
                syncRepository: container.resolve(SyncRepositoryProtocol.self),
                cacheService: container.resolve(CacheService.self),
                networkMonitor: container.resolve(NetworkMonitorProtocol.self)
            )
        )
        
        self._searchViewModel = StateObject(
            wrappedValue: SearchViewModel(
                signRepository: container.resolve(SignRepositoryProtocol.self),
                networkMonitor: container.resolve(NetworkMonitorProtocol.self),
                categoryService: container.resolve(CategoryServiceProtocol.self)
            )
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if isInitialized {
                tabView
            } else {
                LoadingView(message: "Загрузка данных...")
            }
        }
        .task {
            await initializeApp()
        }
        .overlay {
            if syncViewModel.isSyncing {
                syncOverlay
            }
        }
        .onChange(of: syncViewModel.syncError) { _, newValue in
            showSyncError = newValue != nil
        }
        .alert("Ошибка синхронизации", isPresented: $showSyncError) {
            Button("OK") {
                syncViewModel.clearError()
            }
        } message: {
            if let error = syncViewModel.syncError {
                Text(error)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var tabView: some View {
        TabView {
            SearchView(
                viewModel: searchViewModel,
                signRepository: signRepository,
                videoRepository: videoRepository,
                favoritesRepository: favoritesRepository,
                networkMonitor: networkMonitor,
                categoryService: categoryService
            )
            .tabItem {
                Label("Поиск", systemImage: "magnifyingglass")
            }
            
            FavoritesView(
                signRepository: signRepository,
                favoritesRepository: favoritesRepository,
                videoRepository: videoRepository,
                categoryService: categoryService
            )
            .tabItem {
                Label("Избранное", systemImage: "heart.fill")
            }
            
            CategoriesView(
                signRepository: signRepository,
                videoRepository: videoRepository,
                favoritesRepository: favoritesRepository,
                networkMonitor: networkMonitor,
                categoryService: categoryService
            )
            .tabItem {
                Label("Категории", systemImage: "square.grid.2x2")
            }
            
            LessonsView(
                lessonRepository: lessonRepository,
                videoRepository: videoRepository
            )
            .tabItem {
                Label("Обучение", systemImage: "book.fill")
            }
        }
    }
    
    private var syncOverlay: some View {
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
    
    // MARK: - Initialization
    
    private func initializeApp() async {
        guard !isInitialized else { return }
        await categoryService.loadCategories()
        isInitialized = true
    }
}

// MARK: - Preview

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
#endif
