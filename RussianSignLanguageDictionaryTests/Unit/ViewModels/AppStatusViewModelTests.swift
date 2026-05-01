import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class AppStatusViewModelTests: XCTestCase {
    private var sut: AppStatusViewModel!
    private var signRepository: SignRepositorySpy!
    private var networkMonitor: NetworkMonitorSpy!

    override func setUp() {
        super.setUp()
        signRepository = SignRepositorySpy()
        networkMonitor = NetworkMonitorSpy()
    }

    override func tearDown() {
        sut = nil
        signRepository = nil
        networkMonitor = nil
        super.tearDown()
    }

    func testOfflineConnectivityShowsNoInternetIndicator() {
        signRepository.setCurrentDataStatus(.idle)
        networkMonitor.setConnectivityStatus(.disconnected)

        sut = makeSut()

        XCTAssertEqual(sut.indicatorStatus, .noInternet)
    }

    func testServerUnavailableCachedDataShowsServerIndicator() {
        signRepository.setCurrentDataStatus(.usingCachedData(.serverUnavailable))
        networkMonitor.setConnectivityStatus(.connected)

        sut = makeSut()

        XCTAssertEqual(sut.indicatorStatus, .serverUnavailable)
    }

    func testNoInternetCachedDataShowsNoInternetIndicator() {
        signRepository.setCurrentDataStatus(.usingCachedData(.noInternet))
        networkMonitor.setConnectivityStatus(.connected)

        sut = makeSut()

        XCTAssertEqual(sut.indicatorStatus, .noInternet)
    }

    func testConnectedAndUpToDateDataShowsNoIndicator() {
        signRepository.setCurrentDataStatus(.upToDate)
        networkMonitor.setConnectivityStatus(.connected)

        sut = makeSut()

        XCTAssertNil(sut.indicatorStatus)
    }

    func testNoDataWhileOfflineShowsNoIndicator() {
        signRepository.setCurrentDataStatus(.noData(.noInternet))
        networkMonitor.setConnectivityStatus(.disconnected)

        sut = makeSut()

        XCTAssertNil(sut.indicatorStatus)
    }

    func testIndicatorUpdatesWhenRepositoryStatusChanges() async {
        signRepository.setCurrentDataStatus(.updated)
        networkMonitor.setConnectivityStatus(.connected)
        sut = makeSut()

        signRepository.setCurrentDataStatus(.usingCachedData(.serverUnavailable))

        let didUpdate = await waitUntil { self.sut.indicatorStatus == .serverUnavailable }
        XCTAssertTrue(didUpdate)
    }

    func testIndicatorUpdatesWhenConnectivityChanges() async {
        signRepository.setCurrentDataStatus(.upToDate)
        networkMonitor.setConnectivityStatus(.connected)
        sut = makeSut()

        networkMonitor.setConnectivityStatus(.disconnected)

        let didUpdate = await waitUntil {
            self.sut.connectivityStatus == .disconnected && self.sut.indicatorStatus == .noInternet
        }
        XCTAssertTrue(didUpdate)
    }

    private func makeSut() -> AppStatusViewModel {
        AppStatusViewModel(
            signRepository: signRepository,
            networkMonitor: networkMonitor
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollInterval: UInt64 = 20_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return true
            }

            try? await Task.sleep(nanoseconds: pollInterval)
        }

        return condition()
    }
}
