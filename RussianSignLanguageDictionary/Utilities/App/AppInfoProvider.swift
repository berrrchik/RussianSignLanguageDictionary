import Foundation

/// Утилита для получения информации о приложении из Bundle
struct AppInfoProvider {
    // MARK: - Bundle Properties
    
    static var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Словарь РЖЯ"
    }
    
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - App Info Creation
    
    /// Создает объект AppInfo с данными из Bundle и информацией об авторе
    static func createAppInfo() -> AppInfo {
        AppInfo(
            name: appName,
            version: appVersion,
            buildNumber: buildNumber,
            description: "Словарь русского жестового языка — приложение для изучения жестового языка с видео-демонстрациями жестов.",
            author: AuthorInfo(
                name: "Анастасия Берчик",
                email: "berrrchik@mail.ru",
                github: "https://github.com/berrrchik",
                creationDate: Date(timeIntervalSince1970: 1734566400) // Примерная дата создания
            )
        )
    }
}
