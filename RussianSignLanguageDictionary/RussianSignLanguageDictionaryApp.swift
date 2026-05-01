import SwiftUI

@main
@MainActor
struct RussianSignLanguageDictionaryApp: App {

    init() {
        FirebaseConfig.configure()
        DIContainer.shared.configureAppDependencies()
        DIStartupValidation.validateDependencies()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.light)
        }
    }
}
