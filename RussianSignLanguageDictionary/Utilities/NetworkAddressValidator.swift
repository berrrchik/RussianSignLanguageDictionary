import Foundation

/// Валидатор сетевых адресов
/// Определяет тип IP-адреса (локальный/публичный) для диагностики
enum NetworkAddressValidator {
    // MARK: - Local IP Patterns
    
    /// Паттерны локальных IP-адресов согласно RFC 1918
    private static let localIPPatterns: [String] = [
        "192.168.",          // Class C Private
        "10.",               // Class A Private
        "172.16.", "172.17.", "172.18.", "172.19.",
        "172.20.", "172.21.", "172.22.", "172.23.",
        "172.24.", "172.25.", "172.26.", "172.27.",
        "172.28.", "172.29.", "172.30.", "172.31.",  // Class B Private
        "127.0.0.1",         // Loopback
        "localhost"          // Localhost hostname
    ]
    
    // MARK: - Public Methods
    
    /// Проверяет, является ли URL локальным адресом
    /// - Parameter urlString: URL строка для проверки
    /// - Returns: true если это локальный IP-адрес
    static func isLocalAddress(_ urlString: String) -> Bool {
        localIPPatterns.contains { urlString.contains($0) }
    }
    
    /// Проверяет, является ли URL локальным адресом
    /// - Parameter url: URL для проверки
    /// - Returns: true если это локальный IP-адрес
    static func isLocalAddress(_ url: URL) -> Bool {
        isLocalAddress(url.absoluteString)
    }
}

