import Foundation

#if DEBUG
/// Mock реализация VideoRepositoryProtocol для превью и тестов
final class MockVideoRepository: VideoRepositoryProtocol {
    // MARK: - Properties
    
    /// Флаг для симуляции ошибок
    var shouldFail = false
    
    /// Тип ошибки для симуляции
    var errorToThrow: VideoRepositoryError = .invalidURL
    
    /// Mock URL для видео
    var mockURL: URL
    
    // MARK: - Init
    
    init(shouldFail: Bool = false, mockURL: URL = URL(string: "https://example.com/video.mp4")!) {
        self.shouldFail = shouldFail
        self.mockURL = mockURL
    }
    
    // MARK: - VideoRepositoryProtocol
    
    func getVideoURL(for sign: Sign) async throws -> URL {
        if shouldFail {
            throw errorToThrow
        }
        
        // Имитация небольшой задержки
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунда
        
        return mockURL
    }
    
    func preloadVideo(for sign: Sign) async throws {
        // Ничего не делаем в mock
        if shouldFail {
            throw errorToThrow
        }
    }
    
    func clearCache() {
        // Ничего не делаем в mock
    }
}

// MARK: - Shared Instances

extension MockVideoRepository {
    /// Общий экземпляр для использования в Preview
    static let shared = MockVideoRepository()
    
    /// Экземпляр с ошибкой для тестирования error states
    static let withError = MockVideoRepository(shouldFail: true)
    
    /// Экземпляр с кастомным URL
    static func withURL(_ urlString: String) -> MockVideoRepository {
        guard let url = URL(string: urlString) else {
            return MockVideoRepository()
        }
        return MockVideoRepository(mockURL: url)
    }
}
#endif

