import Foundation

/// Thread-safe менеджер кеша в памяти
/// Обеспечивает безопасный доступ к данным из нескольких потоков
final class MemoryCacheManager<T> {
    
    // MARK: - Properties
    
    private let queue: DispatchQueue
    private var cachedData: T?
    
    // MARK: - Initialization
    
    /// Создаёт новый менеджер кеша
    /// - Parameter label: Идентификатор очереди для диагностики
    init(label: String) {
        self.queue = DispatchQueue(label: label)
    }
    
    // MARK: - Public Methods
    
    /// Получает кешированные данные
    /// - Returns: Данные из кеша или nil, если кеш пуст
    func get() -> T? {
        queue.sync { cachedData }
    }
    
    /// Сохраняет данные в кеш
    /// - Parameter data: Данные для сохранения
    func set(_ data: T) {
        queue.sync { cachedData = data }
    }
    
    /// Очищает кеш
    func clear() {
        queue.sync { cachedData = nil }
    }
    
    /// Проверяет наличие данных в кеше
    var hasData: Bool {
        queue.sync { cachedData != nil }
    }
}
