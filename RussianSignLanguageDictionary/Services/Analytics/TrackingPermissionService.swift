import Foundation
import AppTrackingTransparency
import FirebaseAnalytics

/// Сервис для запроса разрешения на отслеживание пользовательской активности
/// 
/// Начиная с iOS 17.4, Apple требует явного разрешения пользователя для отслеживания
/// активности между приложениями и веб-сайтами. Этот сервис обрабатывает запрос разрешения.
enum TrackingPermissionService {
    /// Запрашивает разрешение на отслеживание и настраивает Analytics соответственно
    /// 
    /// Вызывается один раз при первом запуске приложения.
    /// Если пользователь уже дал/отказал разрешение, запрос не показывается.
    static func requestTrackingPermission() {
        // Проверяем, что разрешение ещё не запрашивалось
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            // Если разрешение уже было запрошено, обновляем состояние Analytics
            updateAnalyticsCollection()
            return
        }
        
        // Запрашиваем разрешение с небольшой задержкой для лучшего UX
        Task { @MainActor in
            do {
                // Небольшая задержка, чтобы пользователь увидел интерфейс приложения
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
                
                let status = await ATTrackingManager.requestTrackingAuthorization()
                
                // Обновляем состояние сбора аналитики в зависимости от ответа
                switch status {
                case .authorized, .restricted:
                    // Пользователь разрешил отслеживание (или ограниченное отслеживание)
                    Analytics.setAnalyticsCollectionEnabled(true)
                case .denied, .notDetermined:
                    // Пользователь отказал или статус не определён
                    Analytics.setAnalyticsCollectionEnabled(false)
                @unknown default:
                    Analytics.setAnalyticsCollectionEnabled(false)
                }
            } catch {
                // В случае ошибки отключаем аналитику для безопасности
                Analytics.setAnalyticsCollectionEnabled(false)
                print("⚠️ Ошибка при запросе разрешения на отслеживание: \(error.localizedDescription)")
            }
        }
    }
    
    /// Обновляет состояние сбора аналитики на основе текущего статуса разрешения
    private static func updateAnalyticsCollection() {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .authorized, .restricted:
            Analytics.setAnalyticsCollectionEnabled(true)
        case .denied, .notDetermined:
            Analytics.setAnalyticsCollectionEnabled(false)
        @unknown default:
            Analytics.setAnalyticsCollectionEnabled(false)
        }
    }
}
