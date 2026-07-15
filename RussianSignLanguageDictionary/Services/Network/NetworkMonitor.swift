import Foundation
import Combine
import Network

/// Сервис для проверки доступности сети
///
/// `@unchecked Sendable`: не может быть `actor`, т.к. `NetworkMonitorProtocol.connectivityStatus`
/// — синхронное требование, вызываемое из нескольких ViewModel без `await`.
/// `isMonitoring` защищён `NSLock` (не полагаемся только на "вызывается из init/deinit").
/// `CurrentValueSubject`/`PassthroughSubject` потокобезопасны сами по себе (internal lock),
/// просто не аннотированы `Sendable` в Combine.
final class NetworkMonitor: NetworkMonitorProtocol, @unchecked Sendable {
    // MARK: - Properties

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.rsl.networkMonitor")
    private let connectivitySubject = CurrentValueSubject<ConnectivityStatus, Never>(.unknown)
    private let connectionRestoredSubject = PassthroughSubject<Void, Never>()
    private let isMonitoringLock = NSLock()
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
        let shouldStart = isMonitoringLock.withLock {
            guard !isMonitoring else { return false }
            isMonitoring = true
            return true
        }
        guard shouldStart else { return }
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
        let shouldStop = isMonitoringLock.withLock {
            guard isMonitoring else { return false }
            isMonitoring = false
            return true
        }
        guard shouldStop else { return }
        monitor.cancel()
    }
    
    /// Проверяет доступность интернета асинхронно
    /// - Returns: true, если интернет доступен
    func checkConnection() async -> Bool {
        connectivityStatus == .connected
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
