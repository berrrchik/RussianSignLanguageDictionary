import Foundation
import os.log

/// Валидация DI-конфигурации при запуске приложения.
///
/// Вызывается из `App.init()` после `configureAppDependencies()`.
/// В DEBUG при ошибках — `fatalError`; в release — логирование и отправка в Crashlytics.
enum DIStartupValidation {

    private static let logger = Logger(subsystem: "com.rsl.di", category: "StartupValidation")

    /// Проверяет зарегистрированные зависимости; при ошибках логирует и в release отправляет в Crashlytics.
    static func validateDependencies() {
        let errors = DIContainer.shared.validateConfiguration()
        guard !errors.isEmpty else { return }

        let message = "DI validation failed — missing: \(errors.joined(separator: ", "))"
        logger.critical("\(message)")

        #if DEBUG
        fatalError(message)
        #else
        CrashlyticsErrorReporter.capture(
            DIContainerError.resolutionFailed(message),
            context: ["missingKeys": errors.joined(separator: ", ")],
            subsystem: "com.rsl.di"
        )
        #endif
    }
}
