import Foundation

#if DEBUG
/// Централизованные данные для Preview
/// Используется для единообразного доступа ко всем mock данным в Preview
enum PreviewData {
    // MARK: - Repositories
    
    /// Mock репозиторий для жестов
    static let signRepository = MockSignRepository.shared
    
    /// Mock репозиторий для видео
    static let videoRepository = MockVideoRepository.shared
    
    /// Mock репозиторий для избранного
    static let favoritesRepository = FavoritesRepository.preview
    
    // MARK: - Models - Single Objects
    
    /// Тестовый жест с дефолтными значениями
    static let sign = Sign.mock()
    
    /// Тестовая категория с дефолтными значениями
    static let category = Category.mock()
    
    /// Тестовый метаданные жеста
    static let metadata = SignMetadata.mock()
    
    // MARK: - Models - Collections
    
    /// Массив тестовых жестов
    static let signs = Sign.mockArray()
    
    /// Массив тестовых категорий
    static let categories = Category.mockArray()
    
    // MARK: - Complex Scenarios
    
    /// Жест с длинным описанием для тестирования переноса текста
    static let signWithLongDescription = Sign.mock(
        word: "Длинное описание",
        description: "Это очень длинное описание жеста для тестирования переноса текста и адаптивной верстки в различных размерах экрана. Текст должен корректно отображаться на iPhone SE, iPhone 14 Pro Max и iPad."
    )
    
    /// Жест с множеством ключевых слов для тестирования FlowLayout
    static let signWithManyKeywords = Sign.mock(
        word: "Ключевые слова",
        keywords: [
            "слово1", "слово2", "слово3", "слово4", 
            "слово5", "слово6", "слово7", "слово8",
            "длинноеключевоеслово", "еще одно слово"
        ]
    )
    
    /// Жест без ключевых слов для тестирования Empty State
    static let signWithoutKeywords = Sign.mock(
        word: "Без ключевых слов",
        keywords: []
    )
    
    /// Категория с большим количеством жестов
    static let categoryWithManySigns = Category.mock(
        id: "verbs",
        name: "Глаголы",
        order: 5,
        signCount: 150,
        icon: "figure.run"
    )
}
#endif

