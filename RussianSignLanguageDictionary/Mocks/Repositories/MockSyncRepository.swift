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
    
    func fetchAllData() async throws -> SyncData {
        fetchAllDataCalled = true
        
        if shouldSucceed {
            return dataToReturn ?? createMockSyncData()
        } else {
            throw errorToThrow
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
                embeddings: nil,
                videoId: nil,
                supabaseStoragePath: nil,
                supabaseUrl: nil,
                keywords: nil,
                metadata: nil
            )
        }
        
        return SyncData(
            categories: categories,
            signs: signs,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Reset
    
    func reset() {
        shouldSucceed = true
        errorToThrow = .serverUnavailable
        checkForUpdatesCalled = false
        fetchAllDataCalled = false
        lastUpdatedParameter = nil
        dataToReturn = nil
    }
}
