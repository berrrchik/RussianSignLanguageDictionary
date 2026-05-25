import Foundation

/// Маппер для конвертации ошибок в сообщения
/// Доменные error enum определяют сами сообщения (через `UserFacingError`),
/// этот маппер служит единой точкой входа для всех вызовов из ViewModel-слоя.
enum ErrorMessageMapper {
    static func message(for status: RepositoryDataStatus) -> String {
        switch status {
        case .usingCachedData(.noInternet):
            return "Нет интернета. Показаны сохранённые данные."
        case .usingCachedData(.serverUnavailable):
            return "Сервер недоступен. Показаны сохранённые данные."
        case .noData(.noInternet):
            return "Для первого запуска приложения необходимо подключение к интернету. После загрузки данных приложение будет работать офлайн."
        case .noData(.serverUnavailable):
            return "Сервер временно недоступен. Попробуйте открыть приложение позже."
        case .idle, .loading, .availableLocally, .updated, .upToDate:
            return "Данные загружены."
        }
    }

    static func message(for status: OfflineIndicatorStatus) -> String {
        switch status {
        case .noInternet:
            return "Нет интернета."
        case .serverUnavailable:
            return "Сервер недоступен. Показаны сохранённые данные."
        }
    }

    static func message(for status: FavoriteOfflineStatus) -> String {
        switch status {
        case .pending:
            return "Подготавливается для офлайн."
        case .readyOffline:
            return "Доступно офлайн."
        case .failed:
            return "Не удалось подготовить офлайн."
        }
    }

    // MARK: - Typed Error Overloads (delegate to UserFacingError)

    static func message(for error: SignRepositoryError) -> String { error.userFacingMessage }
    static func message(for error: VideoRepositoryError) -> String { error.userFacingMessage }
    static func message(for error: SyncError) -> String { error.userFacingMessage }
    static func message(for error: CacheError) -> String { error.userFacingMessage }
    static func message(for error: VideoCacheError) -> String { error.userFacingMessage }
    static func message(for error: SBERTSearchError) -> String { error.userFacingMessage }
    static func message(for error: LessonRepositoryError) -> String { error.userFacingMessage }

    // MARK: - Generic Error Mapping

    static func message(for error: Error) -> String {
        (error as? UserFacingError)?.userFacingMessage
            ?? "Произошла ошибка: \(error.localizedDescription)"
    }
}
