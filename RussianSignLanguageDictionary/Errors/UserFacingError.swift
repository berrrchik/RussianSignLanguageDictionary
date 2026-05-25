import Foundation

/// Протокол для ошибок, которые умеют возвращать пользовательское сообщение.
///
/// Все доменные enum-ошибки приложения должны соответствовать этому протоколу,
/// чтобы `ErrorMessageMapper.message(for:)` мог работать без ручного if-let цепочки.
protocol UserFacingError: Error {
    /// Локализованное сообщение для отображения пользователю.
    var userFacingMessage: String { get }
}
