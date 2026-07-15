import Foundation

/// Стандартный JSON декодер для API ответов
/// Используется в SyncRepository и CacheService для единообразия
final class APIJSONDecoder: Sendable {
    // MARK: - Singleton
    
    static let shared = APIJSONDecoder()
    
    // MARK: - Properties
    
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // MARK: - Public Methods
    
    /// Декодирует данные в указанный тип
    /// - Parameters:
    ///   - type: Тип для декодирования
    ///   - data: Данные JSON
    /// - Returns: Декодированный объект
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}

/// Стандартный JSON энкодер для API запросов
/// Используется в CacheService для сохранения данных
final class APIJSONEncoder: Sendable {
    // MARK: - Singleton
    
    static let shared = APIJSONEncoder()
    
    // MARK: - Properties
    
    private let encoder: JSONEncoder
    
    // MARK: - Initialization
    
    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    // MARK: - Public Methods
    
    /// Кодирует объект в JSON данные
    /// - Parameter value: Объект для кодирования
    /// - Returns: Закодированные данные
    func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
}
