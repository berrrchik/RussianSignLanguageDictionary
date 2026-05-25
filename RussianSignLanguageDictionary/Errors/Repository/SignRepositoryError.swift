import Foundation

/// Ошибки репозитория жестов
/// Маппинг в ErrorMessageMapper
enum SignRepositoryError: Error {
    /// JSON файл не найден в Bundle
    case fileNotFound
    
    /// Не удалось прочитать содержимое файла
    case unableToReadFile
    
    /// Ошибка декодирования JSON
    case decodingError(Error)
    
    /// Неверный формат данных
    case invalidDataFormat
    
    /// Данные недоступны (нет кеша и нет интернета)
    case noDataAvailable
    
    // MARK: - Factory Methods
    
    /// Создаёт SignRepositoryError из SyncError
    /// - Parameter error: Ошибка синхронизации
    /// - Returns: Соответствующий SignRepositoryError
    static func from(_ error: Error) -> SignRepositoryError {
        if let syncError = error as? SyncError {
            switch syncError {
            case .noInternet:
                return .noDataAvailable
            case .serverUnavailable, .serverError, .invalidResponse:
                return .noDataAvailable
            case .decodingError(let underlying):
                return .decodingError(underlying)
            case .networkError:
                return .noDataAvailable
            }
        }
        
        if let cacheError = error as? CacheError {
            switch cacheError {
            case .unableToLoad:
                return .noDataAvailable
            case .unableToAccessDocumentsDirectory, .unableToSave:
                return .noDataAvailable
            }
        }
        
        return .noDataAvailable
    }
}

// MARK: - UserFacingError

extension SignRepositoryError: UserFacingError {
    var userFacingMessage: String {
        switch self {
        case .fileNotFound:
            return "Не удалось загрузить данные"
        case .unableToReadFile:
            return "Ошибка чтения файла"
        case .decodingError(let underlyingError):
            return "Ошибка обработки данных: \(underlyingError.localizedDescription)"
        case .invalidDataFormat:
            return "Неверный формат данных"
        case .noDataAvailable:
            return "Данные недоступны. Повторите попытку позже."
        }
    }
}

// MARK: - Equatable

extension SignRepositoryError: Equatable {
    static func == (lhs: SignRepositoryError, rhs: SignRepositoryError) -> Bool {
        switch (lhs, rhs) {
        case (.fileNotFound, .fileNotFound):
            return true
        case (.unableToReadFile, .unableToReadFile):
            return true
        case (.decodingError, .decodingError):
            // Сравниваем только тип ошибки, не содержимое
            return true
        case (.invalidDataFormat, .invalidDataFormat):
            return true
        case (.noDataAvailable, .noDataAvailable):
            return true
        default:
            return false
        }
    }
}
