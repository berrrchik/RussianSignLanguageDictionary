import Foundation

/// Протокол для мониторинга состояния сети
protocol NetworkMonitorProtocol {
    /// Проверяет доступность интернета синхронно
    /// - Returns: true, если интернет доступен
    func isConnected() -> Bool
    
    /// Проверяет доступность интернета асинхронно
    /// - Returns: true, если интернет доступен
    func checkConnection() async -> Bool
}
