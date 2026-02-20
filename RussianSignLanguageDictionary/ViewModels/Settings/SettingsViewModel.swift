import Foundation
import SwiftUI
import UIKit
import MessageUI
import os.log

/// ViewModel для экрана настроек
@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.rsl.settings", category: "SettingsViewModel")
    
    // MARK: - App Storage Settings
    
    /// Автоматический повтор видео после окончания воспроизведения
    @AppStorage("autoRepeatVideo") var autoRepeatVideo: Bool = false
    
    /// Автоматическая загрузка видео при открытии жеста
    @AppStorage("autoDownloadVideo") var autoDownloadVideo: Bool = false
    
    /// Размер шрифта приложения
    @AppStorage("fontSize") var fontSize: FontSize = .medium
    
    /// Тёмная тема
    @AppStorage("darkMode") var darkMode: Bool = false
    
    // MARK: - Font Size
    
    enum FontSize: String, CaseIterable {
        case small = "Маленький"
        case medium = "Средний"
        case large = "Большой"
        
        var scale: CGFloat {
            switch self {
            case .small: return 0.9
            case .medium: return 1.0
            case .large: return 1.15
            }
        }
    }
    
    // MARK: - Published Properties
    
    /// Сообщение об успешной очистке кэша
    @Published var cacheClearedMessage: String?
    
    // MARK: - Dependencies
    
    private let videoRepository: VideoRepositoryProtocol
    
    // MARK: - Init
    
    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            videoRepository: container.resolve(VideoRepositoryProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(videoRepository: VideoRepositoryProtocol) {
        self.videoRepository = videoRepository
    }
    
    // MARK: - Public Methods
    
    /// Очищает кэш видео
    func clearCache() {
        videoRepository.clearCache()
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
    
    /// Открывает страницу приложения в App Store для оставления отзыва
    func openAppStoreReview() {
        // Используем универсальный URL для открытия App Store с поиском приложения
        let appName = appInfo.name.replacingOccurrences(of: " ", with: "+")
        if let url = URL(string: "https://apps.apple.com/search?term=\(appName)") {
            UIApplication.shared.open(url)
        }
    }
    
    /// Открывает email для сообщения об ошибке
    func reportBug() {
        let email = appInfo.author.email ?? "berrrchik@mail.ru"
        let subject = "Ошибка в \(appInfo.name)"
        let body = """
        Версия приложения: \(appInfo.version) (\(appInfo.buildNumber))
        Устройство: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        
        Опишите проблему:
        
        
        """
        
        // Получаем rootViewController более надежным способом
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootViewController = windowScene.windows
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            logger.error("❌ Не удалось получить rootViewController для отправки email")
            return
        }
        
        // Проверяем, доступен ли Mail app
        if MFMailComposeViewController.canSendMail() {
            // Используем MFMailComposeViewController для отправки email
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = MailComposeDelegate.shared
            mailComposer.setToRecipients([email])
            mailComposer.setSubject(subject)
            mailComposer.setMessageBody(body, isHTML: false)
            
            // Находим top-most view controller для корректного отображения
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            
            topController.present(mailComposer, animated: true) { [weak self] in
                self?.logger.info("✅ MFMailComposeViewController представлен")
            }
        } else {
            // Fallback: используем UIActivityViewController для шаринга email
            // Это покажет все доступные способы отправки (Mail, Messages, копирование и т.д.)
            let emailText = """
            To: \(email)
            Subject: \(subject)
            
            \(body)
            """
            
            let activityVC = UIActivityViewController(
                activityItems: [emailText],
                applicationActivities: nil
            )
            
            // Устанавливаем тип контента для email
            activityVC.setValue(subject, forKey: "subject")
            
            // Находим top-most view controller для корректного отображения
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            
            // Для iPad нужно указать sourceView
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topController.view
                popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topController.present(activityVC, animated: true) { [weak self] in
                self?.logger.info("✅ UIActivityViewController представлен")
            }
        }
    }
    
    /// Показывает диалог шаринга приложения
    func shareApp() {
        let appName = appInfo.name
        let appURL = "https://apps.apple.com/app/id\(Bundle.main.bundleIdentifier ?? "")"
        let shareText = "Попробуйте \(appName) - \(appInfo.description) \(appURL)"
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        // Получаем rootViewController более надежным способом
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootViewController = windowScene.windows
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            logger.error("❌ Не удалось получить rootViewController для шаринга")
            return
        }
        
        // Находим top-most view controller для корректного отображения
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        // Для iPad нужно указать sourceView
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        topController.present(activityVC, animated: true) { [weak self] in
            self?.logger.info("✅ UIActivityViewController для шаринга представлен")
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

// MARK: - Mail Compose Delegate

/// Делегат для обработки закрытия MFMailComposeViewController
private class MailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
    static let shared = MailComposeDelegate()
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
