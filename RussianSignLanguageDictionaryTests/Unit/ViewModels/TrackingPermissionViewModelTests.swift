import XCTest
import AppTrackingTransparency
@testable import RussianSignLanguageDictionary

@MainActor
final class TrackingPermissionViewModelTests: XCTestCase {
    func testStart_WhenNotDetermined_ShowsPrimerWithoutRequesting() async {
        let sut = TrackingPermissionViewModel()
        var didRequestAuthorization = false

        await sut.start(
            currentStatus: { .notDetermined },
            requestAuthorization: {
                didRequestAuthorization = true
                return .authorized
            },
            setAnalyticsCollectionEnabled: { _ in }
        )

        XCTAssertTrue(sut.showPrimer)
        XCTAssertFalse(didRequestAuthorization)
    }

    func testStart_WhenAlreadyDetermined_RequestsImmediatelyWithoutShowingPrimer() async {
        let sut = TrackingPermissionViewModel()
        var analyticsEnabled: Bool?

        await sut.start(
            currentStatus: { .authorized },
            requestAuthorization: { .authorized },
            setAnalyticsCollectionEnabled: { analyticsEnabled = $0 }
        )

        XCTAssertFalse(sut.showPrimer)
        XCTAssertEqual(analyticsEnabled, true)
    }

    func testPrimerContinued_WhenCalled_HidesPrimerAndRequestsAuthorization() async {
        let sut = TrackingPermissionViewModel()
        var analyticsEnabled: Bool?
        sut.showPrimer = true

        await sut.primerContinued(
            currentStatus: { .notDetermined },
            requestAuthorization: { .denied },
            setAnalyticsCollectionEnabled: { analyticsEnabled = $0 }
        )

        XCTAssertFalse(sut.showPrimer)
        XCTAssertEqual(analyticsEnabled, false)
    }
}
