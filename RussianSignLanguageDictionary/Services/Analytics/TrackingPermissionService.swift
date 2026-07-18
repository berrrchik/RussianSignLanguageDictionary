import Foundation
import AppTrackingTransparency
import FirebaseAnalytics
import os.log

/// Сервис для запроса разрешения на отслеживание пользовательской активности
///
/// Начиная с iOS 17.4, Apple требует явного разрешения пользователя для отслеживания
/// активности между приложениями и веб-сайтами. Этот сервис обрабатывает запрос разрешения.
@MainActor
enum TrackingPermissionService {
    private static let logger = Logger(subsystem: "com.rsl.tracking", category: "TrackingPermissionService")

    /// Определяет, нужно ли показать прайминг-экран перед системным диалогом ATT
    ///
    /// Прайминг-экран показывается только если пользователь ещё ни разу не отвечал
    /// на системный запрос отслеживания.
    static func shouldShowPrimingScreen(
        status: ATTrackingManager.AuthorizationStatus = ATTrackingManager.trackingAuthorizationStatus
    ) -> Bool {
        status == .notDetermined
    }

    /// Запрашивает разрешение на отслеживание и настраивает Analytics соответственно
    ///
    /// Вызывается один раз при первом запуске приложения (после прайминг-экрана).
    /// Если пользователь уже дал/отказал разрешение, системный запрос не показывается,
    /// но состояние Analytics всё равно синхронизируется с текущим статусом.
    ///
    /// Зависимости от `ATTrackingManager`/`Analytics` инъецируются с дефолтами реальных
    /// системных вызовов — это даёт возможность подменить их в тестах.
    static func requestTrackingPermission(
        currentStatus: () -> ATTrackingManager.AuthorizationStatus = { ATTrackingManager.trackingAuthorizationStatus },
        requestAuthorization: @escaping () async -> ATTrackingManager.AuthorizationStatus = {
            await ATTrackingManager.requestTrackingAuthorization()
        },
        setAnalyticsCollectionEnabled: @escaping (Bool) -> Void = { Analytics.setAnalyticsCollectionEnabled($0) }
    ) async {
        guard currentStatus() == .notDetermined else {
            setAnalyticsCollectionEnabled(isTrackingAllowed(currentStatus()))
            return
        }

        let status = await requestAuthorization()
        setAnalyticsCollectionEnabled(isTrackingAllowed(status))
    }

    private static func isTrackingAllowed(_ status: ATTrackingManager.AuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .restricted:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            logger.error("⚠️ Неизвестный статус разрешения ATT: \(String(describing: status))")
            return false
        }
    }
}
