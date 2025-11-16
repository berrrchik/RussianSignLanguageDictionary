import SwiftUI

@main
struct RussianSignLanguageDictionaryApp: App {
    init() {
        setupDependencies()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    // MARK: - Dependency Injection Setup
    private func setupDependencies() {
        let container = DependencyContainer.shared
        
        #if DEBUG
        print("Dependencies container initialized")
        #endif
    }
}
