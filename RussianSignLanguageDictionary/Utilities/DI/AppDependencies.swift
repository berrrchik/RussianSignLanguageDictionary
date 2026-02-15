import Foundation
import SwiftUI

/// Контейнер зависимостей для передачи через SwiftUI Environment
///
/// Устраняет необходимость прокидывания (prop drilling) отдельных репозиториев
/// через все уровни View-иерархии. Вместо этого зависимости доступны любому View
/// через `@Environment(\.dependencies)`.
///
/// Использование:
/// ```swift
/// struct MyView: View {
///     @Environment(\.dependencies) private var deps
///
///     var body: some View {
///         // deps.signRepository, deps.videoRepository и т.д.
///     }
/// }
/// ```
struct AppDependencies {
    let signRepository: SignRepositoryProtocol
    let videoRepository: VideoRepositoryProtocol
    let favoritesRepository: FavoritesRepositoryProtocol
    let lessonRepository: LessonRepositoryProtocol
    let categoryService: CategoryServiceProtocol
    let networkMonitor: NetworkMonitorProtocol
    
    /// Production-зависимости, резолвятся из DIContainer
    ///
    /// - Important: Вызывайте только после `DIContainer.shared.configureAppDependencies()`
    static func fromContainer(_ container: DIContainer = .shared) -> AppDependencies {
        AppDependencies(
            signRepository: container.resolve(SignRepositoryProtocol.self),
            videoRepository: container.resolve(VideoRepositoryProtocol.self),
            favoritesRepository: container.resolve(FavoritesRepositoryProtocol.self),
            lessonRepository: container.resolve(LessonRepositoryProtocol.self),
            categoryService: container.resolve(CategoryServiceProtocol.self),
            networkMonitor: container.resolve(NetworkMonitorProtocol.self)
        )
    }
}

// MARK: - SwiftUI Environment

private struct AppDependenciesKey: EnvironmentKey {
    /// Default value резолвится из DIContainer (lazy — инициализируется при первом доступе)
    ///
    /// В production: DI сконфигурирован в App.init() до первого обращения
    /// В preview: всегда устанавливается `.environment(\.dependencies, .preview)`
    static let defaultValue = AppDependencies.fromContainer()
}

extension EnvironmentValues {
    /// Зависимости приложения, доступные через `@Environment(\.dependencies)`
    var dependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

// MARK: - Preview Support

#if DEBUG
extension AppDependencies {
    /// Mock-зависимости для SwiftUI Preview
    static var preview: AppDependencies {
        AppDependencies(
            signRepository: PreviewData.signRepository,
            videoRepository: PreviewData.videoRepository,
            favoritesRepository: PreviewData.favoritesRepository,
            lessonRepository: PreviewData.lessonRepository,
            categoryService: PreviewData.categoryService,
            networkMonitor: PreviewData.networkMonitor
        )
    }
}
#endif
