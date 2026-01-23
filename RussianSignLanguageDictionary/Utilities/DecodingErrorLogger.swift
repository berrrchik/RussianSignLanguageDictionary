import Foundation
import os.log

/// Логгер для ошибок декодирования JSON
/// Предоставляет детальную информацию для отладки
enum DecodingErrorLogger {
    
    /// Логирует ошибку декодирования с деталями
    /// - Parameters:
    ///   - error: Ошибка декодирования
    ///   - data: Исходные данные JSON
    ///   - logger: Logger для записи
    static func log(
        _ error: DecodingError,
        data: Data,
        logger: Logger
    ) {
        logger.error("❌ Ошибка декодирования: \(error.localizedDescription)")
        
        logErrorDetails(error, logger: logger)
        logResponseKeys(data: data, logger: logger)
    }
    
    // MARK: - Private Methods
    
    private static func logErrorDetails(_ error: DecodingError, logger: Logger) {
        switch error {
        case .keyNotFound(let key, let context):
            logger.error("   Отсутствует ключ: \(key.stringValue)")
            logger.error("   Путь: \(codingPath(context.codingPath))")
            
        case .dataCorrupted(let context):
            logger.error("   Проблема с данными: \(context.debugDescription)")
            
        case .typeMismatch(let type, let context):
            logger.error("   Несоответствие типа: ожидался \(type)")
            logger.error("   Путь: \(codingPath(context.codingPath))")
            
        case .valueNotFound(let type, let context):
            logger.error("   Значение не найдено: \(type)")
            logger.error("   Путь: \(codingPath(context.codingPath))")
            
        @unknown default:
            break
        }
    }
    
    private static func logResponseKeys(data: Data, logger: Logger) {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        logger.debug("   Ключи в ответе: \(dict.keys.joined(separator: ", "))")
    }
    
    private static func codingPath(_ path: [CodingKey]) -> String {
        path.map { $0.stringValue }.joined(separator: ".")
    }
}
