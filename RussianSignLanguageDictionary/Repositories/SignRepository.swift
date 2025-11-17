import Foundation

/// Репозиторий для работы с данными о жестах из JSON Bundle
final class SignRepository: SignRepositoryProtocol {
    // MARK: - Properties
    
    /// Имя JSON файла в Bundle
    private let fileName: String
    
    /// Кэш загруженных данных
    private var cachedData: SignsData?
    
    /// Очередь для thread-safe операций с кэшем
    private let cacheQueue = DispatchQueue(label: "com.rsl.signRepository.cache")
    
    // MARK: - Initialization
    
    /// Инициализатор репозитория
    /// - Parameter fileName: Имя JSON файла в Bundle (по умолчанию "signs_data")
    init(fileName: String = "signs_data") {
        self.fileName = fileName
    }
    
    // MARK: - SignRepositoryProtocol
    
    func loadAllSigns() async throws -> [Sign] {
        let data = try await loadData()
        return data.signs
    }
    
    func loadCategories() async throws -> [Category] {
        let data = try await loadData()
        return data.categories.sorted { $0.order < $1.order }
    }
    
    func getSign(byId id: String) async throws -> Sign? {
        let signs = try await loadAllSigns()
        return signs.first { $0.id == id }
    }
    
    func getSigns(byCategory categoryId: String) async throws -> [Sign] {
        let signs = try await loadAllSigns()
        return signs.filter { $0.category == categoryId }
    }
    
    func searchSigns(query: String) async throws -> [Sign] {
        guard !query.isEmpty else {
            return []
        }
        
        let signs = try await loadAllSigns()
        let lowercasedQuery = query.lowercased()
        
        return signs.filter { sign in
            // Поиск по слову
            if sign.word.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            // Поиск по ключевым словам
            if sign.keywords.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
                return true
            }
            
            // Поиск по описанию
            if sign.description.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            return false
        }
    }
    
    // MARK: - Private Methods
    
    /// Загружает и кэширует данные из JSON файла
    /// - Returns: Загруженные данные
    /// - Throws: SignRepositoryError в случае ошибки
    private func loadData() async throws -> SignsData {
        // Проверка кэша
        if let cached = cacheQueue.sync(execute: { cachedData }) {
            return cached
        }
        
        // Поиска файла в Bundle
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw SignRepositoryError.fileNotFound
        }
        
        // Чтение данных
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw SignRepositoryError.unableToReadFile
        }
        
        // Декодирование JSON
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let signsData: SignsData
        do {
            signsData = try decoder.decode(SignsData.self, from: data)
        } catch {
            throw SignRepositoryError.decodingError(error)
        }
        
        // Сохранение в кэш
        cacheQueue.sync {
            cachedData = signsData
        }
        
        return signsData
    }
}

