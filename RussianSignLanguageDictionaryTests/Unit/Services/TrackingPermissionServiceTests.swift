import XCTest
import AppTrackingTransparency
@testable import RussianSignLanguageDictionary

@MainActor
final class TrackingPermissionServiceTests: XCTestCase {
    func testShouldShowPrimingScreen_WhenNotDetermined_ReturnsTrue() {
        XCTAssertTrue(TrackingPermissionService.shouldShowPrimingScreen(status: .notDetermined))
    }

    func testShouldShowPrimingScreen_WhenAuthorized_ReturnsFalse() {
        XCTAssertFalse(TrackingPermissionService.shouldShowPrimingScreen(status: .authorized))
    }

    func testShouldShowPrimingScreen_WhenDenied_ReturnsFalse() {
        XCTAssertFalse(TrackingPermissionService.shouldShowPrimingScreen(status: .denied))
    }

    func testShouldShowPrimingScreen_WhenRestricted_ReturnsFalse() {
        XCTAssertFalse(TrackingPermissionService.shouldShowPrimingScreen(status: .restricted))
    }

    // MARK: - requestTrackingPermission

    func testRequestTrackingPermission_WhenNotDeterminedAndUserAuthorizes_EnablesAnalytics() async {
        var analyticsEnabled: Bool?

        await TrackingPermissionService.requestTrackingPermission(
            currentStatus: { .notDetermined },
            requestAuthorization: { .authorized },
            setAnalyticsCollectionEnabled: { analyticsEnabled = $0 }
        )

        XCTAssertEqual(analyticsEnabled, true)
    }

    func testRequestTrackingPermission_WhenNotDeterminedAndUserRestricted_EnablesAnalytics() async {
        var analyticsEnabled: Bool?

        await TrackingPermissionService.requestTrackingPermission(
            currentStatus: { .notDetermined },
            requestAuthorization: { .restricted },
            setAnalyticsCollectionEnabled: { analyticsEnabled = $0 }
        )

        XCTAssertEqual(analyticsEnabled, true)
    }

    func testRequestTrackingPermission_WhenNotDeterminedAndUserDenies_DisablesAnalytics() async {
        var analyticsEnabled: Bool?

        await TrackingPermissionService.requestTrackingPermission(
            currentStatus: { .notDetermined },
            requestAuthorization: { .denied },
            setAnalyticsCollectionEnabled: { analyticsEnabled = $0 }
        )

        XCTAssertEqual(analyticsEnabled, false)
    }

    func testRequestTrackingPermission_WhenNotDeterminedAndSystemRequestStaysUndetermined_DisablesAnalytics() async {
        var analyticsEnabled: Bool?

        await TrackingPermissionService.requestTrackingPermission(
            currentStatus: { .notDetermined },
            requestAuthorization: { .notDetermined },
            setAnalyticsCollectionEnabled: { analyticsEnabled = $0 }
        )

        XCTAssertEqual(analyticsEnabled, false)
    }

    func testRequestTrackingPermission_WhenAlreadyAuthorized_SkipsSystemRequestAndEnablesAnalytics() async {
        var analyticsEnabled: Bool?
        var didRequestAuthorization = false

        await TrackingPermissionService.requestTrackingPermission(
            currentStatus: { .authorized },
            requestAuthorization: {
                didRequestAuthorization = true
                return .authorized
            },
            setAnalyticsCollectionEnabled: { analyticsEnabled = $0 }
        )

        XCTAssertFalse(didRequestAuthorization)
        XCTAssertEqual(analyticsEnabled, true)
    }

    func testRequestTrackingPermission_WhenAlreadyDenied_SkipsSystemRequestAndDisablesAnalytics() async {
        var analyticsEnabled: Bool?
        var didRequestAuthorization = false

        await TrackingPermissionService.requestTrackingPermission(
            currentStatus: { .denied },
            requestAuthorization: {
                didRequestAuthorization = true
                return .authorized
            },
            setAnalyticsCollectionEnabled: { analyticsEnabled = $0 }
        )

        XCTAssertFalse(didRequestAuthorization)
        XCTAssertEqual(analyticsEnabled, false)
    }
}
