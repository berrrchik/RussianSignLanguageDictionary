import Foundation

/// Информация о приложении
struct AppInfo {
    let name: String
    let version: String
    let buildNumber: String
    let description: String
    let author: AuthorInfo
}

/// Информация об авторе приложения
struct AuthorInfo {
    let name: String
    let email: String?
    let github: String?
    let creationDate: Date
}
