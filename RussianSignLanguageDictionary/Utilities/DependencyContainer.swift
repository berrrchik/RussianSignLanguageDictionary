import Foundation

// MARK: - Dependency Container
final class DependencyContainer {
    static let shared = DependencyContainer()
    
    private var dependencies: [String: Any] = [:]
    
    private init() {}
    
    // MARK: - Registration
    func register<T>(_ dependency: T, for type: T.Type) {
        let key = String(describing: type)
        dependencies[key] = dependency
    }
    
    func register<T>(_ factory: @escaping () -> T, for type: T.Type) {
        let key = String(describing: type)
        dependencies[key] = factory
    }
    
    // MARK: - Resolution
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        
        if let factory = dependencies[key] as? () -> T {
            return factory()
        }
        
        return dependencies[key] as? T
    }
    
    func forceResolve<T>(_ type: T.Type) -> T {
        guard let dependency = resolve(type) else {
            fatalError("Dependency \(String(describing: type)) not registered")
        }
        return dependency
    }
    
    // MARK: - Clear
    func clear() {
        dependencies.removeAll()
    }
}

// MARK: - Property Wrapper для DI
@propertyWrapper
struct Injected<T> {
    private let container: DependencyContainer
    
    var wrappedValue: T {
        guard let dependency = container.resolve(T.self) else {
            fatalError("Dependency \(String(describing: T.self)) not registered")
        }
        return dependency
    }
    
    init(container: DependencyContainer = .shared) {
        self.container = container
    }
}

