import Foundation

// MARK: - App Error Types
enum AppError: Error, LocalizedError {
    // Data Layer Errors
    case dataNotFound
    case invalidData
    case decodingFailed(Error)
    case encodingFailed(Error)
    
    // Network/Storage Errors
    case networkError(Error)
    case storageError(Error)
    case invalidURL
    case downloadFailed
    
    // Repository Errors
    case repositoryError(String)
    case cacheError
    
    // Business Logic Errors
    case validationError(String)
    case operationFailed(String)
    
    // Unknown
    case unknown(Error)
    
    // MARK: - LocalizedError Implementation
    var errorDescription: String? {
        switch self {
        case .dataNotFound:
            return "Данные не найдены"
        case .invalidData:
            return "Некорректные данные"
        case .decodingFailed(let error):
            return "Ошибка декодирования: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Ошибка кодирования: \(error.localizedDescription)"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .storageError(let error):
            return "Ошибка хранилища: \(error.localizedDescription)"
        case .invalidURL:
            return "Некорректный URL"
        case .downloadFailed:
            return "Ошибка загрузки"
        case .repositoryError(let message):
            return "Ошибка репозитория: \(message)"
        case .cacheError:
            return "Ошибка кэша"
        case .validationError(let message):
            return "Ошибка валидации: \(message)"
        case .operationFailed(let message):
            return "Операция не выполнена: \(message)"
        case .unknown(let error):
            return "Неизвестная ошибка: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .dataNotFound:
            return "Убедитесь, что данные существуют"
        case .invalidData:
            return "Проверьте формат данных"
        case .networkError:
            return "Проверьте подключение к интернету"
        case .downloadFailed:
            return "Попробуйте еще раз позже"
        default:
            return "Попробуйте перезапустить приложение"
        }
    }
}

// MARK: - Error Handler
final class ErrorHandler {
    static let shared = ErrorHandler()
    
    private init() {}
    
    func handle(_ error: Error) -> String {
        log(error)
        
        if let appError = error as? AppError {
            return appError.errorDescription ?? "Произошла ошибка"
        }
        
        return "Произошла неизвестная ошибка"
    }
    
    private func log(_ error: Error) {
        #if DEBUG
        print("🔴 [ERROR] \(error.localizedDescription)")
        if let appError = error as? AppError {
            print("   Suggestion: \(appError.recoverySuggestion ?? "None")")
        }
        #endif
    }
    
    static func toAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        return .unknown(error)
    }
}

