import SwiftUI

struct MainView: View {
    // MARK: - Properties
    
    private let signRepository: SignRepositoryProtocol
    private let videoRepository: VideoRepositoryProtocol
    private let lessonRepository: LessonRepositoryProtocol
    
    @EnvironmentObject private var favoritesRepository: FavoritesRepository
    @StateObject private var syncViewModel: SyncViewModel
    @State private var isInitialized = false
    
    // MARK: - Init
 
    init(
        signRepository: SignRepositoryProtocol? = nil,
        videoRepository: VideoRepositoryProtocol = VideoRepository(),
        lessonRepository: LessonRepositoryProtocol? = nil,
        syncRepository: SyncRepositoryProtocol? = nil,
        cacheService: CacheService? = nil
    ) {
        let syncRepo = syncRepository ?? SyncRepository()
        let cache = cacheService ?? CacheService()
        
        let signRepo = signRepository ?? SignRepository(
            syncRepository: syncRepo,
            cacheService: cache
        )

        let lessonRepo = lessonRepository ?? LessonRepository(cacheService: cache)
        
        self.signRepository = signRepo
        self.videoRepository = videoRepository
        self.lessonRepository = lessonRepo
        self._syncViewModel = StateObject(
            wrappedValue: SyncViewModel(
                syncRepository: syncRepo,
                cacheService: cache
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
    
    // MARK: - Subviews
    
    private var tabView: some View {
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
        favoritesRepository.setSignRepository(signRepository)
        await CategoryService.loadCategories(from: signRepository)
        isInitialized = true
    }
}

// MARK: - Preview

//#if DEBUG
//struct MainView_Previews: PreviewProvider {
//    static var previews: some View {
//        MainView()
//            .environmentObject(PreviewData.favoritesRepository)
//    }
//}
//#endif
