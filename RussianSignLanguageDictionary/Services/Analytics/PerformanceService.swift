import Foundation
import FirebasePerformance

/// Фасад для отслеживания производительности
/// Инкапсулирует Firebase Performance Monitoring за единым интерфейсом
enum PerformanceService {
    // MARK: - Trace Management
    
    /// Создаёт и начинает новый трейс производительности
    /// - Parameter traceName: Название трейса (максимум 100 символов, только буквы, цифры, подчёркивания)
    /// - Returns: Объект Trace для управления трейсом
    /// - Note: Трейс должен быть остановлен вызовом stopTrace(_:), даже при ошибках (используйте defer)
    /// 
    /// Пример использования:
    /// ```swift
    /// let trace = PerformanceService.startTrace("video_load_network")
    /// defer { PerformanceService.stopTrace(trace) }
    /// // ... код операции ...
    /// ```
    static func startTrace(_ traceName: String) -> Trace {
        guard let trace = Performance.startTrace(name: traceName) else {
            // Если трейс не может быть создан, создаём пустой трейс
            // В реальности это не должно происходить, но для безопасности
            fatalError("Failed to create trace: \(traceName)")
        }
        return trace
    }
    
    /// Останавливает трейс производительности
    /// - Parameter trace: Трейс, который нужно остановить
    /// - Note: Всегда вызывайте этот метод, даже при ошибках. Используйте defer для гарантии вызова.
    static func stopTrace(_ trace: Trace) {
        trace.stop()
    }
    
    // MARK: - Attributes
    
    /// Добавляет атрибут к трейсу для дополнительного контекста
    /// - Parameters:
    ///   - trace: Трейс, к которому добавляется атрибут
    ///   - name: Название атрибута (максимум 40 символов, только буквы, цифры, подчёркивания)
    ///   - value: Значение атрибута (максимум 100 символов)
    /// - Note: Атрибуты помогают фильтровать и анализировать трейсы в Firebase Console.
    ///   Не добавляйте персональные данные (PII) в атрибуты.
    ///   Имена атрибутов автоматически валидируются и очищаются от недопустимых символов.
    /// 
    /// Пример использования:
    /// ```swift
    /// PerformanceService.addAttribute(trace, name: "video_id", value: videoId)
    /// PerformanceService.addAttribute(trace, name: "query", value: searchQuery)
    /// ```
    static func addAttribute(_ trace: Trace, name: String, value: String) {
        // Валидация имени атрибута: только буквы, цифры, подчёркивания, не пустое
        guard !name.isEmpty else {
            return // Игнорируем пустые имена
        }
        
        // Очищаем имя от недопустимых символов (оставляем только буквы, цифры, подчёркивания)
        let sanitizedName = name.filter { $0.isLetter || $0.isNumber || $0 == "_" }
        
        guard !sanitizedName.isEmpty else {
            return // Если после очистки имя пустое, игнорируем
        }
        
        // Ограничиваем длину имени (максимум 40 символов)
        let finalName = String(sanitizedName.prefix(40))
        
        // Ограничиваем длину значения (максимум 100 символов)
        let finalValue = String(value.prefix(100))
        
        trace.setValue(finalValue, forAttribute: finalName)
    }
    
    // MARK: - Metrics
    
    /// Увеличивает метрику трейса на указанное значение
    /// - Parameters:
    ///   - trace: Трейс, к которому добавляется метрика
    ///   - name: Название метрики (максимум 40 символов)
    ///   - value: Значение для увеличения (по умолчанию 1)
    /// - Note: Метрики позволяют отслеживать количественные показатели (размер файла, количество результатов и т.д.)
    /// 
    /// Пример использования:
    /// ```swift
    /// PerformanceService.incrementMetric(trace, name: "video_size_bytes", by: fileSize)
    /// PerformanceService.incrementMetric(trace, name: "results_count", by: Int64(results.count))
    /// ```
    static func incrementMetric(_ trace: Trace, name: String, by value: Int64 = 1) {
        trace.incrementMetric(name, by: value)
    }
    
    // MARK: - Configuration
    
    /// Проверяет, включён ли сбор данных производительности
    /// - Returns: true, если Performance Monitoring активен
    /// - Note: В Debug-сборках Performance Monitoring может быть отключён для уменьшения накладных расходов
    static func isDataCollectionEnabled() -> Bool {
        return Performance.sharedInstance().isDataCollectionEnabled
    }
    
    /// Включает или отключает сбор данных производительности
    /// - Parameter enabled: true для включения, false для отключения
    /// - Note: Используйте для отключения Performance Monitoring в Debug-сборках при необходимости
    static func setDataCollectionEnabled(_ enabled: Bool) {
        Performance.sharedInstance().isDataCollectionEnabled = enabled
    }
}
