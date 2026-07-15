import Foundation
import Combine

/// Mock реализация NetworkMonitorProtocol для тестирования
/// Позволяет симулировать наличие или отсутствие интернета
/// `NetworkMonitorProtocol` требует синхронного `connectivityStatus`, поэтому мок нельзя
/// изолировать к MainActor целиком без переписывания протокола. `@unchecked Sendable`
/// безопасен только потому, что этот мок используется исключительно из Previews и
/// `@MainActor`-тестов — фактически однопоточно, без гонок.
final class MockNetworkMonitor: NetworkMonitorProtocol, @unchecked Sendable {
    // MARK: - Properties
    
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
    
    /// Проверяет доступность интернета асинхронно (mock версия)
    func checkConnection() async -> Bool {
        checkConnectionCallCount += 1
        return connectivityStatus == .connected
    }
    
    // MARK: - Test Helpers
    
    /// Устанавливает состояние подключения для тестирования
    /// - Parameter connected: true если интернет доступен, false если нет
    func setConnected(_ connected: Bool) {
        let previousStatus = connectivitySubject.value
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
