import Foundation
import Combine

/// Mock реализация NetworkMonitorProtocol для тестирования
/// Позволяет симулировать наличие или отсутствие интернета
final class MockNetworkMonitor: NetworkMonitorProtocol {
    // MARK: - Properties
    
    /// Флаг доступности интернета (можно изменять для тестирования)
    var isConnectedValue: Bool = true
    private let connectivitySubject = CurrentValueSubject<ConnectivityStatus, Never>(.connected)

    var connectivityPublisher: AnyPublisher<ConnectivityStatus, Never> {
        connectivitySubject.eraseToAnyPublisher()
    }

    var connectivityStatus: ConnectivityStatus {
        connectivitySubject.value
    }
    
    // MARK: - Initialization
    
    init() {
        // Пустой инициализатор - мок не создаёт реальный NWPathMonitor
    }
    
    // MARK: - NetworkMonitorProtocol
    
    /// Проверяет доступность интернета (mock версия)
    /// - Returns: Значение isConnectedValue
    func isConnected() -> Bool {
        return isConnectedValue
    }
    
    /// Проверяет доступность интернета асинхронно (mock версия)
    /// - Returns: Значение isConnectedValue
    func checkConnection() async -> Bool {
        return isConnectedValue
    }
    
    // MARK: - Test Helpers
    
    /// Устанавливает состояние подключения для тестирования
    /// - Parameter connected: true если интернет доступен, false если нет
    func setConnected(_ connected: Bool) {
        isConnectedValue = connected
        connectivitySubject.send(connected ? .connected : .disconnected)
    }
    
    /// Симулирует потерю интернета
    func simulateNoInternet() {
        setConnected(false)
    }
    
    /// Симулирует восстановление интернета
    func simulateInternetRestored() {
        setConnected(true)
    }
}
