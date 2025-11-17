import Foundation

/// Протокол репозитория для работы с данными о жестах из JSON Bundle
protocol SignRepositoryProtocol {
    /// Загружает все жесты из JSON файла
    /// - Returns: Массив всех жестов
    /// - Throws: SignRepositoryError в случае ошибки
    func loadAllSigns() async throws -> [Sign]
    
    /// Загружает все категории из JSON файла
    /// - Returns: Массив всех категорий
    /// - Throws: SignRepositoryError в случае ошибки
    func loadCategories() async throws -> [Category]
    
    /// Получает жест по его идентификатору
    /// - Parameter id: Уникальный идентификатор жеста
    /// - Returns: Жест или nil, если не найден
    /// - Throws: SignRepositoryError в случае ошибки
    func getSign(byId id: String) async throws -> Sign?
    
    /// Получает все жесты из указанной категории
    /// - Parameter categoryId: Идентификатор категории
    /// - Returns: Массив жестов из указанной категории
    /// - Throws: SignRepositoryError в случае ошибки
    func getSigns(byCategory categoryId: String) async throws -> [Sign]
    
    /// Ищет жесты по запросу (поиск по слову и ключевым словам)
    /// - Parameter query: Поисковый запрос
    /// - Returns: Массив найденных жестов
    /// - Throws: SignRepositoryError в случае ошибки
    func searchSigns(query: String) async throws -> [Sign]
}

