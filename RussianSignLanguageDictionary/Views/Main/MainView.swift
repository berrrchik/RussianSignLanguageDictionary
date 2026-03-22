import SwiftUI

struct MainView: View {
    // MARK: - Properties
    
    @Environment(\.dependencies) private var deps
    @StateObject private var syncViewModel = SyncViewModel()
    @State private var isInitialized = false
    @State private var showSplashOverlay = true
    @State private var showSyncError = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if isInitialized {
                tabView
            }
            if showSplashOverlay {
                StartupSplashScreen()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            await initializeApp()
        }
        .onChange(of: isInitialized) { _, newValue in
            guard newValue else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                showSplashOverlay = false
            }
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
            SearchView()
            .tabItem {
                Label("Поиск", systemImage: "magnifyingglass")
            }
            
            FavoritesView()
            .tabItem {
                Label("Избранное", systemImage: "heart.fill")
            }
            
            CategoriesView()
            .tabItem {
                Label("Категории", systemImage: "square.grid.2x2")
            }
            
            LessonsView()
            .tabItem {
                Label("Обучение", systemImage: "book.fill")
            }
            
            SettingsView()
            .tabItem {
                Label("Настройки", systemImage: "gear")
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

        TrackingPermissionService.requestTrackingPermission()

        async let categoriesLoad: Void = deps.categoryService.loadCategories()
        async let signsLoad: Void = { _ = try? await deps.signRepository.loadAllSigns() }()
        _ = await (categoriesLoad, signsLoad)

        isInitialized = true
    }
}

// MARK: - Preview

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environment(\.dependencies, .preview)
    }
}
#endif
