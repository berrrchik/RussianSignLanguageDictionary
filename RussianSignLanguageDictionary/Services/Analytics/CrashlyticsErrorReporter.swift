import Foundation
import FirebaseCrashlytics

/// Фасад для отправки ошибок в Firebase Crashlytics
/// 
/// Фильтрует ожидаемые ошибки (нет интернета, сервер недоступен)
/// и отправляет только технические проблемы, требующие внимания
enum CrashlyticsErrorReporter {
    /// Отправляет ошибку в Crashlytics с контекстом
    /// - Parameters:
    ///   - error: Ошибка для отправки
    ///   - context: Словарь с дополнительным контекстом
    ///   - subsystem: Подсистема (com.rsl.sync, com.rsl.videoRepository и т.д.)
    static func capture(_ error: Error, context: [String: Any] = [:], subsystem: String = "") {
        // НЕ отправлять ожидаемые ошибки (они не являются багами):
        guard !isExpectedError(error) else { return }
        
        // Получаем экземпляр Crashlytics
        let crashlytics = Crashlytics.crashlytics()
        
        // Устанавливаем пользовательские ключи (custom keys) для контекста
        if !subsystem.isEmpty {
            crashlytics.setCustomValue(subsystem, forKey: "subsystem")
        }
        
        // Добавляем контекст как пользовательские ключи
        for (key, value) in context {
            crashlytics.setCustomValue("\(value)", forKey: key)
        }
        
        // Отправляем ошибку (нефатальную)
        crashlytics.record(error: error)
    }
    
    /// Проверяет, является ли ошибка ожидаемой (не багом)
    /// 
    /// Фильтрует ошибки, которые являются нормальными состояниями приложения:
    /// - Отсутствие интернета (офлайн-режим)
    /// - Сервер недоступен (временные проблемы сети)
    /// - Видео не в кеше (нормально для не избранных жестов)
    /// 
    /// Отправляет только технические проблемы:
    /// - Ошибки сервера (>=500)
    /// - Ошибки декодирования (проблемы с данными)
    /// - Неверный формат ответа
    private static func isExpectedError(_ error: Error) -> Bool {
        switch error {
        // SyncError — ожидаемые состояния офлайн-режима
        case SyncError.noInternet, SyncError.serverUnavailable, SyncError.networkError:
            return true
        
        // SyncError.serverError — отправлять только критические (>=500)
        // true = ожидаемая = НЕ отправлять (4xx), false = критическая = отправить (5xx)
        case SyncError.serverError(let code) where code >= 500:
            return false  // 5xx — критическая ошибка сервера, отправить
        case SyncError.serverError:
            return true   // 4xx — клиентская ошибка, не критично, не отправлять
        
        // VideoRepositoryError — ожидаемые в офлайне
        case VideoRepositoryError.noInternetConnection, VideoRepositoryError.videoNotCached:
            return true
        
        // LessonRepositoryError — ожидаемые в офлайне
        case LessonRepositoryError.noInternetConnection:
            return true
        
        // SBERTSearchError — отправлять только критические
        // httpError содержит statusCode: Int (проверено в SBERTSearchError.swift)
        case SBERTSearchError.httpError(let statusCode) where statusCode >= 500:
            return false  // 5xx — критическая ошибка, отправить
        case SBERTSearchError.httpError:
            return true   // 4xx — не критично, не отправлять
        
        // Остальные ошибки — отправлять (decodingError, invalidResponse, unknown и т.д.)
        default:
            return false
        }
    }
}
