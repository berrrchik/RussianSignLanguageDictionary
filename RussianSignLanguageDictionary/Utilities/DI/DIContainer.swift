import Foundation
import os.log

/// Простой DI-контейнер для управления зависимостями
///
/// Управляет жизненным циклом объектов: singleton (один экземпляр) и transient (новый каждый раз).
/// Использует `NSRecursiveLock` для thread-safety и поддержки вложенного resolve
/// (когда зависимость A зависит от B, которая зависит от C).
///
/// Использование:
/// ```swift
/// // Регистрация
/// container.register(SignRepositoryProtocol.self) {
///     SignRepository(...)
/// }
///
/// // Разрешение
/// let repository = container.resolve(SignRepositoryProtocol.self)
/// ```
///
/// `@unchecked Sendable`: намеренно, не устранимо без разрушения call sites.
/// `NSRecursiveLock` защищает внутреннюю согласованность словарей `factories`/`singletons`
/// (не гонки при записи/чтении), но фабрики типизированы `() -> Any` — не `@Sendable` —
/// т.к. DI осознанно возвращает `@MainActor`-изолированные типы (большинство ViewModel'ов
/// и некоторых репозиториев/сервисов), которые не могут быть `Sendable`. Sendability того,
/// что возвращает фабрика — ответственность вызывающей стороны (resolve вызывается только
/// из init'ов, синхронно, на том же потоке, что и регистрация). Контейнер — singleton,
/// резолвится синхронно из множества init-путей; `actor` сломал бы все call sites.
final class DIContainer: @unchecked Sendable {
    // MARK: - Singleton
    
    /// Общий экземпляр контейнера для всего приложения
    static let shared = DIContainer()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rsl.di", category: "DIContainer")
    
    /// Фабрики для создания зависимостей
    private var factories: [String: () -> Any] = [:]
    
    /// Singleton-экземпляры (кэш)
    private var singletons: [String: Any] = [:]
    
    /// Рекурсивный lock для thread-safe операций
    /// Рекурсивный — потому что resolve() может вызывать resolve() вложенно
    private let lock = NSRecursiveLock()
    
    // MARK: - Initialization
    
    private init() {
        // Приватный инициализатор для singleton
    }
    
    // MARK: - Registration
    
    /// Регистрирует фабрику для создания зависимости (transient — новый экземпляр каждый раз)
    ///
    /// - Parameters:
    ///   - type: Тип зависимости (протокол или класс)
    ///   - factory: Фабрика для создания экземпляра
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        factories[key] = factory
    }
    
    /// Регистрирует singleton (один экземпляр на всё приложение)
    ///
    /// Экземпляр создаётся лениво при первом вызове `resolve()`.
    ///
    /// - Parameters:
    ///   - type: Тип зависимости
    ///   - factory: Фабрика для создания экземпляра (вызовется один раз)
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        
        // unowned безопасен: DIContainer.shared — static singleton, никогда не деаллоцируется
        factories[key] = { [unowned self] in
            // Проверяем кэш — если уже создан, возвращаем
            if let existing = self.singletons[key] as? T {
                return existing
            }
            
            // Создаём и кэшируем
            let instance = factory()
            self.singletons[key] = instance
            return instance
        }
    }
    
    // MARK: - Resolution
    
    /// Разрешает зависимость (создаёт или возвращает существующий экземпляр)
    ///
    /// - Parameter type: Тип зависимости
    /// - Returns: Экземпляр зависимости
    ///
    /// В DEBUG — `fatalError` при отсутствии зависимости.
    /// В release — логирование + non-fatal отчёт перед `fatalError`,
    /// чтобы ошибка конфигурации фиксировалась в Crashlytics.
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        
        lock.lock()
        defer { lock.unlock() }
        
        if let singleton = singletons[key] as? T {
            return singleton
        }
        
        guard let factory = factories[key] else {
            handleResolutionFailure("Зависимость '\(key)' не зарегистрирована в DI-контейнере")
        }
        
        guard let instance = factory() as? T else {
            handleResolutionFailure("Фабрика для '\(key)' вернула неверный тип")
        }
        
        return instance
    }
    
    /// Обрабатывает ошибку разрешения зависимости с разным поведением для DEBUG и release
    private func handleResolutionFailure(_ message: String) -> Never {
        #if DEBUG
        fatalError("❌ \(message)")
        #else
        logger.critical("❌ DI: \(message)")
        CrashlyticsErrorReporter.capture(
            DIContainerError.resolutionFailed(message),
            context: ["message": message],
            subsystem: "com.rsl.di"
        )
        fatalError("❌ DI configuration error: \(message)")
        #endif
    }
    
    /// Безопасное разрешение зависимости (возвращает nil, если не зарегистрирована)
    ///
    /// - Parameter type: Тип зависимости
    /// - Returns: Экземпляр зависимости или nil
    func resolveOptional<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        
        lock.lock()
        defer { lock.unlock() }
        
        // Проверяем singleton кэш
        if let singleton = singletons[key] as? T {
            return singleton
        }
        
        // Получаем фабрику
        guard let factory = factories[key] else {
            return nil
        }
        
        // Создаём экземпляр
        return factory() as? T
    }
    
    // MARK: - Cleanup
    
    /// Очищает все зависимости (полезно для тестов)
    ///
    /// - Warning: Используйте только в тестах!
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        factories.removeAll()
        singletons.removeAll()
    }
    
    /// Проверяет, зарегистрирована ли зависимость
    ///
    /// - Parameter type: Тип зависимости
    /// - Returns: true, если зависимость зарегистрирована
    func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        return factories[key] != nil
    }
    
    // MARK: - Validation
    
    /// Проверяет, что все ожидаемые зависимости зарегистрированы в контейнере
    ///
    /// Сравнивает список типов, используемых в `configureAppDependencies()`,
    /// с реально зарегистрированными фабриками.
    /// Не вызывает фабрики — только проверяет их наличие (safe для production).
    ///
    /// - Returns: Массив имён типов, для которых фабрика не найдена.
    ///   Пустой массив — все зависимости зарегистрированы.
    func validateConfiguration() -> [String] {
        let expectedKeys: [String] = [
            String(describing: NetworkMonitorProtocol.self),
            String(describing: CacheServiceProtocol.self),
            String(describing: VideoCacheServiceProtocol.self),
            String(describing: HybridSearchServiceBuilderProtocol.self),
            String(describing: SyncRepositoryProtocol.self),
            String(describing: SignRepositoryProtocol.self),
            String(describing: VideoRepositoryProtocol.self),
            String(describing: LessonRepositoryProtocol.self),
            String(describing: FavoritesRepositoryProtocol.self),
            String(describing: OfflinePreparationServiceProtocol.self),
        ]
        
        lock.lock()
        defer { lock.unlock() }
        
        var missingKeys: [String] = []
        for key in expectedKeys {
            if factories[key] == nil {
                missingKeys.append(key)
                logger.error("❌ DI validation: фабрика для '\(key)' не зарегистрирована")
            }
        }
        
        if missingKeys.isEmpty {
            logger.info("✅ DI validation: все \(expectedKeys.count) зависимостей зарегистрированы")
        }
        
        return missingKeys
    }
}

// MARK: - DIContainerError

enum DIContainerError: LocalizedError {
    case resolutionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .resolutionFailed(let message):
            return "DI resolution failed: \(message)"
        }
    }
}

