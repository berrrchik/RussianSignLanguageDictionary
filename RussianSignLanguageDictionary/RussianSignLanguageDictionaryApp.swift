import SwiftUI

@main
struct RussianSignLanguageDictionaryApp: App {
        
    init() {
        FirebaseConfig.configure()
        DIContainer.shared.configureAppDependencies()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.light)
        }
    }
}
