import Foundation
import Combine

#if DEBUG
/// Mock реализация SignRepositoryProtocol для превью и тестов
final class MockSignRepository: SignRepositoryProtocol {
    // MARK: - Properties
    
    /// Флаг для симуляции ошибок
    var shouldFail = false
    
    /// Тестовые жесты
    var mockSigns: [Sign] = Sign.mockArray()
    
    /// Тестовые категории
    var mockCategories: [Category] = Category.mockArray()
    
    /// Тип ошибки для симуляции
    var errorToThrow: SignRepositoryError = .fileNotFound

    private let dataUpdatedSubject = PassthroughSubject<SyncData, Never>()
    private let dataStatusSubject = CurrentValueSubject<RepositoryDataStatus, Never>(.updated)
    
    // MARK: - Init
    
    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }
    
    // MARK: - SignRepositoryProtocol

    var dataUpdatedPublisher: AnyPublisher<SyncData, Never> {
        dataUpdatedSubject.eraseToAnyPublisher()
    }

    var dataStatusPublisher: AnyPublisher<RepositoryDataStatus, Never> {
        dataStatusSubject.eraseToAnyPublisher()
    }

    var currentDataStatus: RepositoryDataStatus {
        dataStatusSubject.value
    }
    
    func loadAllSigns() async throws -> [Sign] {
        if shouldFail {
            throw errorToThrow
        }
        return mockSigns
    }
    
    func loadCategories() async throws -> [Category] {
        if shouldFail {
            throw errorToThrow
        }
        return mockCategories.sorted { $0.order < $1.order }
    }
    
    func getSign(byId id: String) async throws -> Sign? {
        if shouldFail {
            throw errorToThrow
        }
        return mockSigns.first { $0.id == id }
    }
    
    func getSigns(byCategory categoryId: String) async throws -> [Sign] {
        if shouldFail {
            throw errorToThrow
        }
        return mockSigns.filter { $0.categoryId == categoryId }
    }
    
    func searchSigns(query: String) async throws -> [Sign] {
        if shouldFail {
            throw errorToThrow
        }
        
        guard !query.isEmpty else {
            return mockSigns
        }
        
        let lowercasedQuery = query.lowercased()
        return mockSigns.filter { sign in
            sign.word.lowercased().contains(lowercasedQuery)
        }
    }

    func cachedSigns() -> [Sign]? {
        shouldFail ? nil : mockSigns
    }

    func setDataStatus(_ status: RepositoryDataStatus) {
        dataStatusSubject.send(status)
    }
}

// MARK: - Shared Instance

extension MockSignRepository {
    /// Общий экземпляр для использования в Preview
    static let shared = MockSignRepository()
    
    /// Экземпляр с ошибкой для тестирования error states
    static let withError = MockSignRepository(shouldFail: true)
    
    /// Экземпляр с пустыми данными
    static let empty: MockSignRepository = {
        let repo = MockSignRepository()
        repo.mockSigns = []
        repo.mockCategories = []
        return repo
    }()
}
#endif
