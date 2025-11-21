import Foundation

#if DEBUG
extension Sign {
    /// Создает тестовый объект Sign для превью и тестов
    /// - Parameters:
    ///   - id: Уникальный идентификатор жеста
    ///   - word: Слово на русском языке
    ///   - category: Категория жеста
    ///   - description: Описание жеста
    ///   - keywords: Ключевые слова для поиска
    /// - Returns: Тестовый объект Sign
    static func mock(
        id: String = "sign_001",
        word: String = "Привет",
        category: String = "greetings",
        description: String = "Жест для тестирования",
        keywords: [String]? = nil
    ) -> Sign {
        Sign(
            id: id,
            word: word,
            description: description,
            category: category,
            videoId: "video_\(id)",
            supabaseStoragePath: "test/\(id).mp4",
            supabaseUrl: "https://example.com/\(id).mp4",
            keywords: keywords ?? [word.lowercased()],
            embeddings: [],
            metadata: .mock()
        )
    }
    
    /// Создает массив тестовых жестов
    static func mockArray() -> [Sign] {
        [
            .mock(id: "sign_001", word: "Привет", category: "greetings"),
            .mock(id: "sign_002", word: "Спасибо", category: "greetings"),
            .mock(id: "sign_003", word: "До свидания", category: "greetings")
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

