import Foundation

/// Информация о Всероссийском обществе глухих (ВОГ)
struct VOGInfo {
    let name: String
    let description: String
    let websiteURL: URL
    let contactsURL: URL
    let phone: String
    let socialNetworks: [SocialNetwork]
}

/// Информация о социальной сети ВОГ
struct SocialNetwork {
    let name: String
    let url: URL
    let iconName: String // SF Symbol name
}
