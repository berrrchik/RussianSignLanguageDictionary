import SwiftUI

struct MainView: View {
    // MARK: - Properties
    
    @StateObject private var syncViewModel: SyncViewModel
    @StateObject private var appStatusViewModel: AppStatusViewModel
    @State private var showSyncError = false

    @MainActor
    init() {
        _syncViewModel = StateObject(wrappedValue: SyncViewModel())
        _appStatusViewModel = StateObject(wrappedValue: AppStatusViewModel())
    }

    @MainActor
    init(
        syncViewModel: SyncViewModel,
        appStatusViewModel: AppStatusViewModel
    ) {
        _syncViewModel = StateObject(wrappedValue: syncViewModel)
        _appStatusViewModel = StateObject(wrappedValue: appStatusViewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if syncViewModel.startupStatus.isReady {
                tabView
                    .environmentObject(appStatusViewModel)
                    .transition(.opacity)
            }

            switch syncViewModel.startupStatus {
            case .idle, .loading:
                StartupSplashScreen()
                    .transition(.opacity)
                    .zIndex(1)
            case .blocked(let reason):
                ErrorView(
                    message: ErrorMessageMapper.message(for: .noData(reason)),
                    retryAction: retryInitialization
                )
                .zIndex(1)
            case .ready, .readyUsingCachedData:
                EmptyView()
            }
        }
        .animation(.easeOut(duration: 0.4), value: syncViewModel.startupStatus.isReady)
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
            Tab("Поиск", systemImage: "magnifyingglass") {
                SearchView()
            }
            
            Tab("Избранное", systemImage: "heart.fill") {
                FavoritesView()
            }
            
            Tab("Категории", systemImage: "square.grid.2x2") {
                CategoriesView()
            }
            
            Tab("Обучение", systemImage: "book.fill") {
                LessonsView()
            }
            
            Tab("Настройки", systemImage: "gear") {
                SettingsView()
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
        TrackingPermissionService.requestTrackingPermission()
        await syncViewModel.initializeApp()
    }

    private func retryInitialization() {
        Task {
            await syncViewModel.initializeApp(force: true)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MainView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        MainView(
            syncViewModel: SyncViewModel(
                syncRepository: MockSyncRepository(),
                signRepository: PreviewData.signRepository,
                cacheService: CacheService(),
                networkMonitor: PreviewData.networkMonitor
            ),
            appStatusViewModel: AppStatusViewModel(
                signRepository: PreviewData.signRepository,
                networkMonitor: PreviewData.networkMonitor
            )
        )
            .environment(\.dependencies, .preview)
    }
}
#endif
