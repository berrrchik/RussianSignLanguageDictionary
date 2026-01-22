import Foundation

/// Мок-репозиторий синхронизации для тестирования
final class MockSyncRepository: SyncRepositoryProtocol {
    
    // MARK: - Configuration
    
    /// Флаг успешности операций
    var shouldSucceed = true
    
    /// Ошибка для выброса при неудаче
    var errorToThrow: SyncError = .serverUnavailable
    
    /// Метаданные для возврата
    var metadataToReturn = SyncMetadata(
        lastUpdated: Date(),
        hasUpdates: true
    )
    
    /// Данные для возврата
    var dataToReturn: SyncData?
    
    // MARK: - Call Tracking
    
    var checkForUpdatesCalled = false
    var fetchAllDataCalled = false
    var lastUpdatedParameter: Date?
    var cachedDataProviderCalled = false
    
    // MARK: - SyncRepositoryProtocol
    
    func checkForUpdates(lastUpdated: Date?) async throws -> SyncMetadata {
        checkForUpdatesCalled = true
        lastUpdatedParameter = lastUpdated
        
        if shouldSucceed {
            return metadataToReturn
        } else {
            throw errorToThrow
        }
    }
    
    func fetchAllData(cachedDataProvider: @escaping () throws -> SyncData) async throws -> SyncData {
        fetchAllDataCalled = true
        
        if shouldSucceed {
            return dataToReturn ?? createMockSyncData()
        } else {
            // При ошибке можно попробовать использовать кеш
            do {
                cachedDataProviderCalled = true
                return try cachedDataProvider()
            } catch {
                throw errorToThrow
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Создаёт моковые данные для тестов
    private func createMockSyncData() -> SyncData {
        let categories = [
            Category(
                id: "cat1",
                name: "Тестовая категория 1",
                order: 1,
                signCount: 5,
                icon: "hand.raised",
                color: "#FF5733",
                createdAt: Date(),
                updatedAt: Date()
            ),
            Category(
                id: "cat2",
                name: "Тестовая категория 2",
                order: 2,
                signCount: 5,
                icon: "heart",
                color: "#33FF57",
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        let signs = (1...10).map { index in
            Sign(
                id: "sign\(index)",
                word: "Тестовый жест \(index)",
                description: "Описание жеста \(index)",
                categoryId: index <= 5 ? "cat1" : "cat2",
                videos: [
                    SignVideo(
                        id: index,
                        url: "https://example.com/video\(index).mp4",
                        contextDescription: "Основное видео",
                        order: 1,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                ],
                synonyms: nil,
                videoId: nil,
                supabaseStoragePath: nil,
                supabaseUrl: nil,
                keywords: nil,
                metadata: nil
            )
        }
        
        let lessons = [
            Lesson(
                id: "lesson_1",
                title: "Тестовый урок 1",
                description: "Описание тестового урока 1",
                videoUrl: "https://example.com/lesson1.mp4",
                order: 1,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Lesson(
                id: "lesson_2",
                title: "Тестовый урок 2",
                description: "Описание тестового урока 2",
                videoUrl: "https://example.com/lesson2.mp4",
                order: 2,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        return SyncData(
            categories: categories,
            signs: signs,
            lessons: lessons,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Reset
    
    func reset() {
        shouldSucceed = true
        errorToThrow = .serverUnavailable
        checkForUpdatesCalled = false
        fetchAllDataCalled = false
        cachedDataProviderCalled = false
        lastUpdatedParameter = nil
        dataToReturn = nil
    }
}
