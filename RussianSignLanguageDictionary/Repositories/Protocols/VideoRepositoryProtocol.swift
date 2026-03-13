import Foundation

/// Протокол репозитория для работы с видео с сервера
///
/// Поддерживает двухуровневое кеширование:
/// - **Долгосрочный кеш (useFavoritesCache: true)**: файлы на диске для избранных жестов
/// - **Краткосрочный кеш (useFavoritesCache: false)**: файлы в `Caches/`, управляются LRU
///
/// Краткосрочный кеш хранится в `cachesDirectory` — штатное место для кешей iOS.
/// Сохраняется между обычными сессиями, но может быть очищен системой
/// при нехватке места на устройстве (что допустимо для кеша).
protocol VideoRepositoryProtocol {
    /// Проверяет наличие видео в любом локальном кеше (синхронно)
    ///
    /// Проверяет в порядке приоритета:
    /// 1. Краткосрочный кеш (файлы в `Caches/video_short_term_cache/`)
    /// 2. Долгосрочный кеш (файлы избранных на диске)
    ///
    /// - Parameter video: Модель видео
    /// - Returns: Локальный file URL или nil, если видео не кешировано
    func cachedVideoURL(for video: SignVideo) -> URL?
    
    /// Получает URL видео для указанного жеста (для обратной совместимости)
    /// - Parameter sign: Модель жеста
    /// - Returns: URL видео файла
    /// - Throws: VideoRepositoryError в случае ошибки
    func getVideoURL(for sign: Sign) async throws -> URL
    
    /// Получает URL видео для указанного урока
    /// - Parameter lesson: Модель урока
    /// - Returns: URL видео файла
    /// - Throws: VideoRepositoryError в случае ошибки
    func getVideoURL(for lesson: Lesson) async throws -> URL
    
    /// Получает URL видео для указанного видео объекта
    /// - Parameters:
    ///   - video: Модель видео
    ///   - useFavoritesCache: Использовать долгосрочный кеш для избранного (по умолчанию false)
    /// - Returns: URL видео файла
    /// - Throws: VideoRepositoryError в случае ошибки
    ///
    /// При `useFavoritesCache: true`:
    /// - Загружает видео в файловый кеш на диске
    /// - Видео сохраняется и доступно офлайн
    ///
    /// При `useFavoritesCache: false`:
    /// - Загружает видео в краткосрочный кеш (`Caches/`)
    /// - Кеш сохраняется между сессиями, но может быть очищен системой
    func getVideoURL(for video: SignVideo, useFavoritesCache: Bool) async throws -> URL
    
    /// Предзагружает видео в кэш для указанного жеста
    /// - Parameter sign: Модель жеста
    /// - Throws: VideoRepositoryError в случае ошибки
    func preloadVideo(for sign: Sign) async throws
    
    /// Предзагружает видео в долгосрочный кеш избранного
    /// - Parameters:
    ///   - video: Видео для предзагрузки
    ///   - useFavoritesCache: Использовать долгосрочный кеш (по умолчанию true)
    /// - Throws: VideoRepositoryError в случае ошибки
    func preloadVideo(video: SignVideo, useFavoritesCache: Bool) async throws
    
    /// Очищает кэш видео URL
    func clearCache()
}

