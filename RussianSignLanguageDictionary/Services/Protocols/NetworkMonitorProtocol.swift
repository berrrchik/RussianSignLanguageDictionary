import Foundation
import Combine

/// Протокол для мониторинга состояния сети
protocol NetworkMonitorProtocol: Sendable {
    /// Публикует изменения состояния подключения.
    var connectivityPublisher: AnyPublisher<ConnectivityStatus, Never> { get }

    /// Публикует событие восстановления подключения после офлайн-состояния.
    var connectionRestoredPublisher: AnyPublisher<Void, Never> { get }

    /// Возвращает текущее нормализованное состояние подключения.
    var connectivityStatus: ConnectivityStatus { get }

    /// Проверяет доступность интернета асинхронно
    /// - Returns: true, если интернет доступен
    func checkConnection() async -> Bool
}
