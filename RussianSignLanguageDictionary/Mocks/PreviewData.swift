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
    static let favoritesRepository = MockFavoritesRepository.shared
    
    /// Mock репозиторий для уроков
    static let lessonRepository = MockLessonRepository()
    
    /// Mock монитор сети
    static let networkMonitor = MockNetworkMonitor()
    
    /// Mock сервис категорий
    static let categoryService = MockCategoryService.shared
    
    // MARK: - Models - Single Objects
    
    /// Тестовый жест с дефолтными значениями
    static let sign = Sign.mock()
    
    /// Тестовая категория с дефолтными значениями
    static let category = Category.mock()
    
    /// Тестовый урок с дефолтными значениями
    static let lesson = Lesson.mock()
    
    // MARK: - Models - Collections
    
    /// Массив тестовых жестов
    static let signs = Sign.mockArray()
    
    /// Массив тестовых категорий
    static let categories = Category.mockArray()
    
    /// Массив тестовых уроков
    static let lessons = Lesson.mockLessons()
    
    // MARK: - Complex Scenarios
    
    /// Жест с длинным описанием для тестирования переноса текста
    static let signWithLongDescription = Sign.mock(
        word: "Длинное описание",
        description: "Это очень длинное описание жеста для тестирования переноса текста и адаптивной верстки в различных размерах экрана. Текст должен корректно отображаться на iPhone SE, iPhone 14 Pro Max и iPad."
    )
    
    /// Жест с множеством видео для тестирования навигации
    static let signWithMultipleVideos = Sign.mockWithMultipleVideos()
    
    /// Жест с синонимами для тестирования SynonymListView
    static let signWithSynonyms = Sign.mock(
        id: "sign_001",
        word: "Привет",
        categoryId: "greetings",
        description: "Жест приветствия",
        synonyms: [
            SignSynonym(id: "sign_002", word: "Здравствуй"),
            SignSynonym(id: "sign_003", word: "Добро пожаловать"),
            SignSynonym(id: "sign_004", word: "Рад видеть")
        ]
    )
    
    /// Категория с большим количеством жестов
    static let categoryWithManySigns = Category.mock(
        id: "verbs",
        name: "Глаголы",
        order: 5,
        signCount: 150,
        icon: "figure.run"
    )
    
    // MARK: - Dependencies
    
    /// Группа зависимостей для SignDetailView
    static var signDetailDependencies: SignDetailView.Dependencies {
        .init(
            signRepository: signRepository,
            videoRepository: videoRepository,
            favoritesRepository: favoritesRepository,
            categoryService: categoryService
        )
    }
}
#endif
