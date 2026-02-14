import Foundation

#if DEBUG
extension Sign {
    /// Создает тестовый объект Sign для превью и тестов
    /// - Parameters:
    ///   - id: Уникальный идентификатор жеста
    ///   - word: Слово на русском языке
    ///   - categoryId: Идентификатор категории жеста
    ///   - description: Описание жеста
    ///   - videos: Массив видео для жеста
    ///   - synonyms: Массив синонимов жеста
    /// - Returns: Тестовый объект Sign
    static func mock(
        id: String = "sign_001",
        word: String = "Привет",
        categoryId: String = "greetings",
        description: String = "Жест для тестирования",
        videos: [SignVideo]? = nil,
        synonyms: [SignSynonym]? = nil
    ) -> Sign {
        Sign(
            id: id,
            word: word,
            description: description,
            categoryId: categoryId,
            videos: videos ?? [
                SignVideo(
                    id: 1,
                    url: "https://example.com/\(id).mp4",
                    contextDescription: "Основное видео для жеста",
                    order: 0,
                    createdAt: nil,
                    updatedAt: nil
                )
            ],
            synonyms: synonyms
        )
    }
    
    /// Создает массив тестовых жестов
    static func mockArray() -> [Sign] {
        [
            .mock(id: "sign_001", word: "Привет", categoryId: "greetings"),
            .mock(id: "sign_002", word: "Спасибо", categoryId: "greetings"),
            .mock(id: "sign_003", word: "До свидания", categoryId: "greetings")
        ]
    }
    
    /// Жест с множеством видео для тестирования навигации
    static func mockWithMultipleVideos(
        id: String = "sign_multiple",
        word: String = "Жест с несколькими видео",
        categoryId: String = "greetings"
    ) -> Sign {
        .mock(
            id: id,
            word: word,
            categoryId: categoryId,
            videos: [
                SignVideo(
                    id: 1,
                    url: "https://example.com/\(id)_1.mp4",
                    contextDescription: "Первое видео",
                    order: 0,
                    createdAt: nil,
                    updatedAt: nil
                ),
                SignVideo(
                    id: 2,
                    url: "https://example.com/\(id)_2.mp4",
                    contextDescription: "Второе видео",
                    order: 1,
                    createdAt: nil,
                    updatedAt: nil
                ),
                SignVideo(
                    id: 3,
                    url: "https://example.com/\(id)_3.mp4",
                    contextDescription: "Третье видео",
                    order: 2,
                    createdAt: nil,
                    updatedAt: nil
                )
            ]
        )
    }
}

extension SignMetadata {
    /// Создает тестовый объект SignMetadata для превью и тестов
    static func mock(
        duration: Double = 3.0,
        fileSize: Int = 500000,
        resolution: String = "1080x1920",
        format: String = "mp4",
        fps: Int = 30
    ) -> SignMetadata {
        SignMetadata(
            duration: duration,
            fileSize: fileSize,
            resolution: resolution,
            format: format,
            fps: fps
        )
    }
}
#endif

