import Foundation
import AppTrackingTransparency
import FirebaseAnalytics

/// ViewModel для управления показом прайминг-экрана и запросом ATT-разрешения
@MainActor
final class TrackingPermissionViewModel: ObservableObject {
    /// Показывать ли прайминг-шторку перед системным диалогом ATT
    @Published var showPrimer = false

    /// Решает, показать прайминг-экран или сразу синхронизировать состояние Analytics
    func start(
        currentStatus: @escaping () -> ATTrackingManager.AuthorizationStatus = { ATTrackingManager.trackingAuthorizationStatus },
        requestAuthorization: @escaping () async -> ATTrackingManager.AuthorizationStatus = {
            await ATTrackingManager.requestTrackingAuthorization()
        },
        setAnalyticsCollectionEnabled: @escaping (Bool) -> Void = { Analytics.setAnalyticsCollectionEnabled($0) }
    ) async {
        if TrackingPermissionService.shouldShowPrimingScreen(status: currentStatus()) {
            showPrimer = true
        } else {
            await TrackingPermissionService.requestTrackingPermission(
                currentStatus: currentStatus,
                requestAuthorization: requestAuthorization,
                setAnalyticsCollectionEnabled: setAnalyticsCollectionEnabled
            )
        }
    }

    /// Вызывается после того как пользователь нажал "Продолжить" на прайминг-экране
    func primerContinued(
        currentStatus: @escaping () -> ATTrackingManager.AuthorizationStatus = { ATTrackingManager.trackingAuthorizationStatus },
        requestAuthorization: @escaping () async -> ATTrackingManager.AuthorizationStatus = {
            await ATTrackingManager.requestTrackingAuthorization()
        },
        setAnalyticsCollectionEnabled: @escaping (Bool) -> Void = { Analytics.setAnalyticsCollectionEnabled($0) }
    ) async {
        showPrimer = false
        await TrackingPermissionService.requestTrackingPermission(
            currentStatus: currentStatus,
            requestAuthorization: requestAuthorization,
            setAnalyticsCollectionEnabled: setAnalyticsCollectionEnabled
        )
    }
}
