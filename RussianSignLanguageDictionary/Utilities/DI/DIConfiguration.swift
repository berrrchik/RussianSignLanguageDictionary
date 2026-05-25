import Foundation

// MARK: - App Configuration

extension DIContainer {
    /// Настраивает все зависимости приложения
    ///
    /// Вызывается один раз при запуске приложения в `App.swift`.
    /// Порядок регистрации важен: базовые сервисы → репозитории → высокоуровневые компоненты.
    ///
    /// **Примечание:** `SyncViewModel` не регистрируется в контейнере,
    /// т.к. он помечен `@MainActor` и должен создаваться на main thread.
    @MainActor
    func configureAppDependencies() {
        // 1. Базовые сервисы (singleton)
        registerSingleton(NetworkMonitorProtocol.self) {
            NetworkMonitor()
        }

        registerSingleton(CacheService.self) {
            CacheService()
        }

        registerSingleton(VideoCacheServiceProtocol.self) { [unowned self] in
            VideoCacheService(
                networkMonitor: self.resolve(NetworkMonitorProtocol.self)
            )
        }

        registerSingleton(HybridSearchServiceBuilderProtocol.self) {
            HybridSearchServiceBuilder()
        }

        // 2. Репозитории (singleton)
        registerSingleton(SyncRepositoryProtocol.self) {
            SyncRepository()
        }

        registerSingleton(SignRepositoryProtocol.self) { [unowned self] in
            SignRepository(
                syncRepository: self.resolve(SyncRepositoryProtocol.self),
                cacheService: self.resolve(CacheService.self),
                networkMonitor: self.resolve(NetworkMonitorProtocol.self)
            )
        }

        registerSingleton(VideoRepositoryProtocol.self) { [unowned self] in
            VideoRepository(
                videoCacheService: self.resolve(VideoCacheServiceProtocol.self),
                networkMonitor: self.resolve(NetworkMonitorProtocol.self)
            )
        }

        registerSingleton(LessonRepositoryProtocol.self) { [unowned self] in
            LessonRepository(
                cacheService: self.resolve(CacheService.self)
            )
        }

        let favoritesRepository = FavoritesRepository(
            videoCacheService: resolve(VideoCacheServiceProtocol.self)
        )
        registerSingleton(FavoritesRepositoryProtocol.self) {
            favoritesRepository
        }

        // 3. Сервисы высокого уровня (зависят от репозиториев)
        registerSingleton(OfflinePreparationServiceProtocol.self) { [unowned self] in
            OfflinePreparationService(
                videoRepository: self.resolve(VideoRepositoryProtocol.self),
                favoritesRepository: self.resolve(FavoritesRepositoryProtocol.self)
            )
        }
    }
}
