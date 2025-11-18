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
}

