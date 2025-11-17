import Foundation

/// Репозиторий для работы с видео из Supabase Storage
final class VideoRepository: VideoRepositoryProtocol {
    // MARK: - Properties
    
    /// Кэш для URL видео
    private let cache = NSCache<NSString, NSURL>()
    
    /// Очередь для thread-safe операций
    private let cacheQueue = DispatchQueue(label: "com.rsl.videoRepository.cache")
    
    // MARK: - Initialization
    
    init() {
        // Настройка кэша
        cache.countLimit = 100 // Храним до 100 URL
    }
    
    // MARK: - VideoRepositoryProtocol
    
    func getVideoURL(for sign: Sign) async throws -> URL {
        // Проверка кэша
        let cacheKey = sign.id as NSString
        if let cachedURL = cacheQueue.sync(execute: { cache.object(forKey: cacheKey) as URL? }) {
            return cachedURL
        }
        
        // Используем публичный URL из модели Sign
        guard let url = URL(string: sign.supabaseUrl) else {
            throw VideoRepositoryError.invalidURL
        }
        
        // Сохранение в кэш
        cacheQueue.sync {
            cache.setObject(url as NSURL, forKey: cacheKey)
        }
        
        return url
    }
    
    func preloadVideo(for sign: Sign) async throws {
        // Загрузка URL в кэш
        _ = try await getVideoURL(for: sign)
    }
    
    func clearCache() {
        cacheQueue.sync {
            cache.removeAllObjects()
        }
    }
}

