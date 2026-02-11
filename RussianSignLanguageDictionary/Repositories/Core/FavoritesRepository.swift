import Foundation
import Combine
import os.log

/// Репозиторий для работы с избранными жестами через UserDefaults
///
/// Автоматически управляет кешем видео при добавлении/удалении из избранного:
/// - При добавлении жеста в избранное - предзагружает все его видео в долгосрочный кеш
/// - При удалении из избранного - очищает долгосрочный кеш для всех видео жеста
final class FavoritesRepository: FavoritesRepositoryProtocol, ObservableObject {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.favorites", category: "FavoritesRepository")
    
    /// Ключ для хранения избранного в UserDefaults
    private let favoritesKey = "com.rsl.favorites"
    
    /// UserDefaults для хранения данных
    private let userDefaults: UserDefaults
    
    /// Publisher для изменений избранного
    @Published private(set) var favoritesPublisher: [String] = []
    
    /// Репозиторий жестов для получения данных о видео
    ///
    /// Используется для предзагрузки/очистки видео кеша при изменениях в избранном.
    /// Зависимость разрешается через DI-контейнер при создании.
    private let signRepository: SignRepositoryProtocol
    
    /// Сервис кеширования видео
    private let videoCacheService: VideoCacheServiceProtocol
    
    // MARK: - Initialization
    
    /// Инициализатор репозитория
    /// - Parameters:
    ///   - userDefaults: UserDefaults (по умолчанию .standard)
    ///   - signRepository: Репозиторий жестов для получения данных о видео
    ///   - videoCacheService: Сервис кеширования видео
    init(
        userDefaults: UserDefaults = .standard,
        signRepository: SignRepositoryProtocol,
        videoCacheService: VideoCacheServiceProtocol
    ) {
        self.userDefaults = userDefaults
        self.signRepository = signRepository
        self.videoCacheService = videoCacheService
        self.favoritesPublisher = self.getFavorites()
    }
    
    // MARK: - FavoritesRepositoryProtocol
    
    func getFavorites() -> [String] {
        // UserDefaults.standard является thread-safe для чтения
        // Поэтому можем безопасно читать с любого потока
        return userDefaults.stringArray(forKey: favoritesKey) ?? []
    }
    
    func addFavorite(signId: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.addFavorite(signId: signId)
            }
            return
        }
        
        var favorites = getFavorites()
        
        guard !favorites.contains(signId) else {
            return
        }
        
        favorites.append(signId)
        userDefaults.set(favorites, forKey: favoritesKey)
        
        favoritesPublisher = favorites
        
        logger.info("⭐️ Жест \(signId) добавлен в избранное")
        
        // Предзагрузка видео в долгосрочный кеш
        preloadVideosForFavorite(signId: signId)
    }
    
    func removeFavorite(signId: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.removeFavorite(signId: signId)
            }
            return
        }
        
        var favorites = getFavorites()
        favorites.removeAll { $0 == signId }
        
        userDefaults.set(favorites, forKey: favoritesKey)
        
        favoritesPublisher = favorites
        
        logger.info("💔 Жест \(signId) удалён из избранного")
        
        // Очистка долгосрочного кеша для видео жеста
        clearVideoCacheForSign(signId: signId)
    }
    
    func isFavorite(signId: String) -> Bool {
        let favorites = getFavorites()
        return favorites.contains(signId)
    }
    
    func clearAllFavorites() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.clearAllFavorites()
            }
            return
        }
        
        userDefaults.removeObject(forKey: favoritesKey)
        
        favoritesPublisher = []
        
        logger.info("🗑️ Все избранные жесты очищены")
        
        // Очистка всего долгосрочного кеша видео
        videoCacheService.clearAllCache()
    }
    
    // MARK: - Video Cache Management
    
    /// Предзагружает все видео жеста в долгосрочный кеш
    /// - Parameter signId: ID жеста
    private func preloadVideosForFavorite(signId: String) {
        Task {
            do {
                if let sign = try await signRepository.getSign(byId: signId),
                   let videos = sign.videos {
                    logger.info("📥 Предзагрузка \(videos.count) видео для избранного жеста \(signId)...")
                    
                    await videoCacheService.preloadVideos(videos)
                    
                    logger.info("✅ Предзагрузка видео для жеста \(signId) завершена")
                }
            } catch {
                logger.error("❌ Ошибка предзагрузки видео для \(signId): \(error.localizedDescription)")
            }
        }
    }
    
    /// Очищает долгосрочный кеш для всех видео жеста
    /// - Parameter signId: ID жеста
    private func clearVideoCacheForSign(signId: String) {
        Task {
            do {
                if let sign = try await signRepository.getSign(byId: signId),
                   let videos = sign.videos {
                    videoCacheService.clearCache(for: signId, videos: videos)
                    logger.info("🗑️ Кеш видео для жеста \(signId) очищен (\(videos.count) видео)")
                }
            } catch {
                logger.error("❌ Ошибка очистки кеша для \(signId): \(error.localizedDescription)")
            }
        }
    }
}
