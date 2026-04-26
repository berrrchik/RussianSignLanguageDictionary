import Foundation
import Combine
import Network

/// Сервис для проверки доступности сети
final class NetworkMonitor: NetworkMonitorProtocol {
    // MARK: - Properties
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.rsl.networkMonitor")
    private let connectivitySubject = CurrentValueSubject<ConnectivityStatus, Never>(.unknown)
    private let connectionRestoredSubject = PassthroughSubject<Void, Never>()
    private var isMonitoring = false

    var connectivityPublisher: AnyPublisher<ConnectivityStatus, Never> {
        connectivitySubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var connectionRestoredPublisher: AnyPublisher<Void, Never> {
        connectionRestoredSubject.eraseToAnyPublisher()
    }

    var connectivityStatus: ConnectivityStatus {
        Self.makeConnectivityStatus(from: monitor.currentPath.status)
    }
    
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
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            let previousStatus = self.connectivitySubject.value
            let newStatus = Self.makeConnectivityStatus(from: path.status)

            self.connectivitySubject.send(newStatus)

            if previousStatus != .connected, newStatus == .connected {
                self.connectionRestoredSubject.send(())
            }
        }
        connectivitySubject.send(connectivityStatus)
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
        connectivityStatus == .connected
    }
    
    /// Проверяет доступность интернета асинхронно
    /// - Returns: true, если интернет доступен
    func checkConnection() async -> Bool {
        isConnected()
    }

    private static func makeConnectivityStatus(from status: NWPath.Status) -> ConnectivityStatus {
        switch status {
        case .satisfied:
            return .connected
        case .unsatisfied, .requiresConnection:
            return .disconnected
        @unknown default:
            return .unknown
        }
    }
}
