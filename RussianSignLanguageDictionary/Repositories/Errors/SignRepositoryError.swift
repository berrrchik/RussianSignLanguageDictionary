import Foundation

/// Ошибки репозитория жестов
enum SignRepositoryError: LocalizedError {
    /// JSON файл не найден в Bundle
    case fileNotFound
    
    /// Не удалось прочитать содержимое файла
    case unableToReadFile
    
    /// Ошибка декодирования JSON
    case decodingError(Error)
    
    /// Неверный формат данных
    case invalidDataFormat
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "JSON файл с данными о жестах не найден в приложении"
        case .unableToReadFile:
            return "Не удалось прочитать файл с данными о жестах"
        case .decodingError(let error):
            return "Ошибка при декодирования данных: \(error.localizedDescription)"
        case .invalidDataFormat:
            return "Неверный формат данных в JSON файле"
        }
    }
}

