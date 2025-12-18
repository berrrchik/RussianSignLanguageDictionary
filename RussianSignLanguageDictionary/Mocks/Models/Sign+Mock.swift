import Foundation

#if DEBUG
extension Sign {
    /// Создает тестовый объект Sign для превью и тестов
    /// - Parameters:
    ///   - id: Уникальный идентификатор жеста
    ///   - word: Слово на русском языке
    ///   - categoryId: Идентификатор категории жеста
    ///   - description: Описание жеста
    ///   - keywords: Ключевые слова для поиска
    ///   - synonyms: Массив синонимов жеста
    /// - Returns: Тестовый объект Sign
    static func mock(
        id: String = "sign_001",
        word: String = "Привет",
        categoryId: String = "greetings",
        description: String = "Жест для тестирования",
        keywords: [String]? = nil,
        synonyms: [SignSynonym]? = nil
    ) -> Sign {
        Sign(
            id: id,
            word: word,
            description: description,
            categoryId: categoryId,
            videos: nil,
            synonyms: synonyms,
            embeddings: nil,
            videoId: "video_\(id)",
            supabaseStoragePath: "test/\(id).mp4",
            supabaseUrl: "https://example.com/\(id).mp4",
            keywords: keywords ?? [word.lowercased()],
            metadata: .mock()
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

