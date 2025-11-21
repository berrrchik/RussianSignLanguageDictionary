import SwiftUI

@main
struct RussianSignLanguageDictionaryApp: App {
    
    // MARK: - Properties
    
    @StateObject private var favoritesRepository = FavoritesRepository()
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(favoritesRepository)
                .preferredColorScheme(.light)
        }
    }
}
