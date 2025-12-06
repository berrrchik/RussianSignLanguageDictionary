import Foundation
import Network

/// Сервис для проверки доступности сети
final class NetworkMonitor {
    // MARK: - Properties
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.rsl.networkMonitor")
    private var isMonitoring = false
    
    // MARK: - Initialization
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Methods
    
    /// Начинает мониторинг сети
    private func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitor.start(queue: queue)
    }
    
    /// Останавливает мониторинг сети
    private func stopMonitoring() {
        guard isMonitoring else { return }
        monitor.cancel()
        isMonitoring = false
    }
    
    /// Проверяет доступность интернета
    /// - Returns: true, если интернет доступен
    func isConnected() -> Bool {
        return monitor.currentPath.status == .satisfied
    }
    
    /// Проверяет доступность интернета асинхронно
    /// - Returns: true, если интернет доступен
    func checkConnection() async -> Bool {
        return await withCheckedContinuation { continuation in
            let currentPath = monitor.currentPath
            continuation.resume(returning: currentPath.status == .satisfied)
        }
    }
}
