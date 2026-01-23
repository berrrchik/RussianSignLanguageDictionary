import Foundation
import os.log

/// Actor для координации параллельных загрузок одних данных
/// Предотвращает дублирование запросов при параллельных вызовах
actor DataLoadCoordinator<T: Sendable> {
    
    // MARK: - Properties
    
    private var activeTask: Task<T, Error>?
    private let logger: Logger
    
    // MARK: - Initialization
    
    /// Создаёт координатор загрузки
    /// - Parameters:
    ///   - subsystem: Подсистема для логгера
    ///   - category: Категория для логгера
    init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
    }
    
    // MARK: - Public Methods
    
    /// Выполняет или ожидает существующую задачу загрузки
    /// Если уже есть активная задача — ожидает её результат
    /// Если нет — создаёт новую задачу
    /// - Parameter work: Асинхронная работа для выполнения
    /// - Returns: Результат загрузки
    func getOrCreateTask(
        perform work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        if let existingTask = activeTask {
            logger.debug("⏳ Обнаружена активная задача, ожидание...")
            return try await existingTask.value
        }
        
        logger.debug("🚀 Создание новой задачи загрузки")
        let newTask = Task<T, Error> {
            defer { Task { await self.clearTask() } }
            return try await work()
        }
        
        activeTask = newTask
        let result = try await newTask.value
        logger.debug("✅ Задача загрузки завершена")
        return result
    }
    
    // MARK: - Private Methods
    
    private func clearTask() {
        activeTask = nil
        logger.debug("🧹 Задача очищена")
    }
}
