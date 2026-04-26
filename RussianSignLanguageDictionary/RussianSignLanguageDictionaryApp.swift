import SwiftUI

@main
struct RussianSignLanguageDictionaryApp: App {

    init() {
        FirebaseConfig.configure()
        DIContainer.shared.configureAppDependencies()
        _ = DIContainer.shared.resolveOptional(FavoritesRepositoryProtocol.self)?.reconcileOfflineState()
        DIStartupValidation.validateDependencies()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.light)
        }
    }
}
