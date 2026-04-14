import Foundation

/// Actor для координации параллельных загрузок видео
///
/// Гарантирует потокобезопасность без блокировки потоков (в отличие от NSLock).
/// Предотвращает дублирование загрузок: если несколько запросов запрашивают одно и то же видео,
/// все они получат результат одной загрузки.
///
/// ## Использование
/// ```swift
/// let coordinator = VideoDownloadCoordinator()
/// let (task, isExisting) = await coordinator.getOrCreateTask(videoId: 123) {
///     // Загрузка видео
///     return try await downloadVideo(id: 123)
/// }
/// ```
actor VideoDownloadCoordinator {
    // MARK: - Properties
    
    /// Активные загрузки: videoId → Task загрузки
    private var inFlightDownloads: [Int: Task<URL, Error>] = [:]
    
    // MARK: - Public Methods
    
    /// Получает существующую задачу загрузки или создаёт новую
    ///
    /// Если видео уже загружается другим запросом, возвращает существующую задачу.
    /// Иначе создаёт новую задачу и сохраняет её в словаре.
    ///
    /// - Parameters:
    ///   - videoId: ID видео
    ///   - downloadTask: Замыкание для создания задачи загрузки
    /// - Returns: Кортеж из Task загрузки и флага `isExisting` (true, если задача уже была в процессе)
    func getOrCreateTask(
        videoId: Int,
        downloadTask: @escaping () async throws -> URL
    ) -> (task: Task<URL, Error>, isExisting: Bool) {
        // Проверяем, не загружается ли уже
        if let existingTask = inFlightDownloads[videoId] {
            return (existingTask, true)
        }
        
        // Создаём новую задачу
        let task = Task<URL, Error> { [weak self] in
            do {
                let url = try await downloadTask()
                await self?.removeTask(videoId: videoId)
                return url
            } catch {
                await self?.removeTask(videoId: videoId)
                throw error
            }
        }
        
        inFlightDownloads[videoId] = task
        return (task, false)
    }
    
    // MARK: - Private Methods
    
    /// Удаляет задачу из словаря после завершения
    /// - Parameter videoId: ID видео
    private func removeTask(videoId: Int) {
        inFlightDownloads.removeValue(forKey: videoId)
    }
}
