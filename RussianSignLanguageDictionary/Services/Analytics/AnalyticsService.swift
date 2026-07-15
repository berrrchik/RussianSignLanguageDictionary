import Foundation
import FirebaseAnalytics
import UIKit

/// Фасад для отправки событий аналитики
/// Инкапсулирует Firebase Analytics за единым интерфейсом
/// 
/// Автоматически добавляет метаданные к каждому событию:
/// - Версия приложения
/// - Версия iOS
/// - Locale пользователя
@MainActor
enum AnalyticsService {
    // MARK: - Screen Tracking
    
    /// Логирует открытие экрана
    /// - Parameters:
    ///   - screenName: Название экрана
    ///   - screenClass: Класс экрана (обычно имя View)
    static func logScreenView(screenName: String, screenClass: String) {
        var parameters: [String: Any] = [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass
        ]
        parameters.merge(enrichParameters()) { (_, new) in new }
        
        Analytics.logEvent(AnalyticsEventScreenView, parameters: parameters)
    }
    
    // MARK: - Sign Events
    
    /// Просмотр жеста
    /// - Parameters:
    ///   - signId: ID жеста
    ///   - word: Слово жеста
    ///   - categoryId: ID категории
    static func logSignViewed(signId: String, word: String, categoryId: String) {
        logEvent("sign_viewed", parameters: [
            "sign_id": signId,
            "word": word,
            "category_id": categoryId
        ])
    }
    
    /// Добавление в избранное
    /// - Parameters:
    ///   - signId: ID жеста
    ///   - word: Слово жеста
    static func logSignFavorited(signId: String, word: String) {
        logEvent("sign_favorited", parameters: [
            "sign_id": signId,
            "word": word
        ])
    }
    
    /// Удаление из избранного
    /// - Parameters:
    ///   - signId: ID жеста
    ///   - word: Слово жеста
    static func logSignUnfavorited(signId: String, word: String) {
        logEvent("sign_unfavorited", parameters: [
            "sign_id": signId,
            "word": word
        ])
    }
    
    // MARK: - Search Events
    
    /// Поисковый запрос
    /// - Parameters:
    ///   - query: Поисковый запрос
    ///   - resultsCount: Количество результатов
    ///   - searchType: Тип поиска ("hybrid", "text", "sbert")
    static func logSearch(query: String, resultsCount: Int, searchType: String) {
        logEvent("search_performed", parameters: [
            "query": query,
            "results_count": resultsCount,
            "search_type": searchType
        ])
    }
    
    // MARK: - Category Events
    
    /// Открытие категории
    /// - Parameters:
    ///   - categoryId: ID категории
    ///   - categoryName: Название категории
    static func logCategoryOpened(categoryId: String, categoryName: String) {
        logEvent("category_opened", parameters: [
            "category_id": categoryId,
            "category_name": categoryName
        ])
    }
    
    // MARK: - Lesson Events
    
    /// Просмотр урока
    /// - Parameters:
    ///   - lessonId: ID урока
    ///   - lessonTitle: Название урока
    static func logLessonViewed(lessonId: String, lessonTitle: String) {
        logEvent("lesson_viewed", parameters: [
            "lesson_id": lessonId,
            "lesson_title": lessonTitle
        ])
    }
    
    // MARK: - Video Events
    
    /// Начало воспроизведения видео
    /// - Parameters:
    ///   - videoId: ID видео
    ///   - source: Источник видео ("cache_favorites", "cache_short_term", "network")
    static func logVideoPlayed(videoId: String, source: String) {
        logEvent("video_played", parameters: [
            "video_id": videoId,
            "source": source
        ])
    }
    
    // MARK: - Sync Events
    
    /// Синхронизация данных завершена успешно
    /// - Parameters:
    ///   - signsCount: Количество жестов
    ///   - categoriesCount: Количество категорий
    ///   - lessonsCount: Количество уроков
    static func logSyncCompleted(signsCount: Int, categoriesCount: Int, lessonsCount: Int) {
        logEvent("sync_completed", parameters: [
            "signs_count": signsCount,
            "categories_count": categoriesCount,
            "lessons_count": lessonsCount
        ])
    }
    
    /// Синхронизация данных завершена с ошибкой
    /// - Parameter errorType: Тип ошибки
    static func logSyncFailed(errorType: String) {
        var parameters: [String: Any] = [
            "error_type": errorType
        ]
        parameters.merge(enrichParameters()) { (_, new) in new }
        
        Analytics.logEvent("sync_failed", parameters: parameters)
    }
    
    // MARK: - Private Helpers
    
    /// Обогащает параметры события метаданными приложения
    /// - Returns: Словарь с метаданными (версия приложения, iOS версия, locale)
    private static func enrichParameters() -> [String: Any] {
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let iosVersion = UIDevice.current.systemVersion
        let localeId = Locale.current.identifier
        
        return [
            "app_version": bundleVersion,
            "ios_version": iosVersion,
            "locale_id": localeId
        ]
    }
    
    /// Логирует событие с автоматическим обогащением метаданными
    /// - Parameters:
    ///   - eventName: Название события
    ///   - parameters: Параметры события (будут обогащены метаданными)
    static func logEvent(_ eventName: String, parameters: [String: Any] = [:]) {
        var enrichedParameters = parameters
        enrichedParameters.merge(enrichParameters()) { (_, new) in new }
        
        Analytics.logEvent(eventName, parameters: enrichedParameters)
    }
}
