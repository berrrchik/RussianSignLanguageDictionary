import SwiftUI

@main
struct RussianSignLanguageDictionaryApp: App {
        
    init() {
        FirebaseConfig.configure()    // 1. Firebase (Analytics + Crashlytics)
        DIContainer.shared.configureAppDependencies() // 2. Затем DI
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.light)
        }
    }
}
