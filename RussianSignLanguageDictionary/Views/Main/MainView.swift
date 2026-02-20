import SwiftUI

struct MainView: View {
    // MARK: - Properties
    
    @Environment(\.dependencies) private var deps
    @StateObject private var syncViewModel = SyncViewModel()
    @State private var isInitialized = false
    @State private var showSyncError = false
    
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
        
        await deps.categoryService.loadCategories()
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
