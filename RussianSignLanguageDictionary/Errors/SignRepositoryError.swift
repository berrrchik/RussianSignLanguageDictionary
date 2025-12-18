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

