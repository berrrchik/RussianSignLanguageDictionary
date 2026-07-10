import Foundation
import SwiftUI
import UIKit
import os.log

/// ViewModel для экрана настроек
@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Logger

    private let logger = Logger(subsystem: "com.rsl.settings", category: "SettingsViewModel")

    // MARK: - Published Properties
    
    /// Сообщение об успешной очистке кэша
    @Published var cacheClearedMessage: String?
    
    // MARK: - Dependencies
    
    private let videoRepository: VideoRepositoryProtocol
    private let favoritesRepository: FavoritesRepositoryProtocol
    
    // MARK: - Init
    
    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            videoRepository: container.resolve(VideoRepositoryProtocol.self),
            favoritesRepository: container.resolve(FavoritesRepositoryProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(
        videoRepository: VideoRepositoryProtocol,
        favoritesRepository: FavoritesRepositoryProtocol
    ) {
        self.videoRepository = videoRepository
        self.favoritesRepository = favoritesRepository
    }
    
    // MARK: - Public Methods
    
    /// Очищает кэш видео
    func clearCache() {
        videoRepository.clearCache()
        Task {
            await favoritesRepository.reconcileOfflineState()
        }
        cacheClearedMessage = "Кэш успешно очищен"
        logger.info("✅ Кэш очищен пользователем")
        
        // Сбросить сообщение через 2 секунды
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                cacheClearedMessage = nil
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Информация о приложении
    var appInfo: AppInfo {
        AppInfoProvider.createAppInfo()
    }
    
    /// Информация о ВОГ
    var vogInfo: VOGInfo {
        VOGInfo(
            name: "Всероссийское общество глухих (ВОГ)",
            description: "Всероссийское общество глухих — общероссийская общественная организация инвалидов по слуху, созданная для защиты прав и интересов глухих граждан России.",
            websiteURL: URL(string: "https://voginfo.ru")!,
            contactsURL: URL(string: "https://voginfo.ru/about/contacts/")!,
            phone: "+7 (499) 255 6704",
            socialNetworks: [
                SocialNetwork(
                    name: "ВКонтакте",
                    url: URL(string: "https://vk.com/voginfo")!,
                    iconName: "link"
                ),
                SocialNetwork(
                    name: "Telegram",
                    url: URL(string: "https://t.me/voginfo")!,
                    iconName: "paperplane"
                )
            ]
        )
    }
}
