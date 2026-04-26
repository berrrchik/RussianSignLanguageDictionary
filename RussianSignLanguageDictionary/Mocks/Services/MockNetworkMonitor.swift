import Foundation
import Combine

/// Mock реализация NetworkMonitorProtocol для тестирования
/// Позволяет симулировать наличие или отсутствие интернета
final class MockNetworkMonitor: NetworkMonitorProtocol {
    // MARK: - Properties
    
    /// Флаг доступности интернета (можно изменять для тестирования)
    var isConnectedValue: Bool = true
    private(set) var isConnectedCallCount = 0
    private(set) var checkConnectionCallCount = 0
    private let connectivitySubject = CurrentValueSubject<ConnectivityStatus, Never>(.connected)
    private let connectionRestoredSubject = PassthroughSubject<Void, Never>()

    var connectivityPublisher: AnyPublisher<ConnectivityStatus, Never> {
        connectivitySubject.eraseToAnyPublisher()
    }

    var connectionRestoredPublisher: AnyPublisher<Void, Never> {
        connectionRestoredSubject.eraseToAnyPublisher()
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
        isConnectedCallCount += 1
        return isConnectedValue
    }
    
    /// Проверяет доступность интернета асинхронно (mock версия)
    /// - Returns: Значение isConnectedValue
    func checkConnection() async -> Bool {
        checkConnectionCallCount += 1
        return isConnectedValue
    }
    
    // MARK: - Test Helpers
    
    /// Устанавливает состояние подключения для тестирования
    /// - Parameter connected: true если интернет доступен, false если нет
    func setConnected(_ connected: Bool) {
        let previousStatus = connectivitySubject.value
        isConnectedValue = connected
        let newStatus: ConnectivityStatus = connected ? .connected : .disconnected
        connectivitySubject.send(newStatus)

        if previousStatus != .connected, newStatus == .connected {
            connectionRestoredSubject.send(())
        }
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
