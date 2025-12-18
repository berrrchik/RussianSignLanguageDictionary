import Foundation

@MainActor
final class CategoriesViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var categories: [Category] = []
    @Published private(set) var state: ViewState = .idle
    
    /// Индикатор офлайн-режима (данные загружены из кеша, интернет недоступен)
    @Published private(set) var isOfflineMode: Bool = false
    
    /// Сообщение о работе в офлайн-режиме
    @Published private(set) var offlineMessage: String?
    
    // MARK: - ViewState
    
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }
    
    // MARK: - Dependencies
    
    private let signRepository: SignRepositoryProtocol
    private let networkMonitor: NetworkMonitorProtocol
    
    // MARK: - Init
    
    init(
        signRepository: SignRepositoryProtocol,
        networkMonitor: NetworkMonitorProtocol = NetworkMonitor()
    ) {
        self.signRepository = signRepository
        self.networkMonitor = networkMonitor
    }
    
    // MARK: - Public Methods
    
    func loadCategories() async {
        state = .loading
        isOfflineMode = false
        offlineMessage = nil
        
        do {
            let loadedCategories = try await signRepository.loadCategories()
            categories = loadedCategories.sorted { $0.order < $1.order }
            state = .loaded
            
            // Проверка доступности интернета после загрузки данных
            let isConnected = await networkMonitor.checkConnection()
            if !isConnected {
                isOfflineMode = true
                offlineMessage = "Работа в офлайн-режиме. Показаны сохранённые данные."
            }
        } catch let error as SignRepositoryError {
            state = .error(errorMessage(for: error))
        } catch {
            state = .error("Произошла неизвестная ошибка")
        }
    }
    
    func refreshCategories() async {
        await loadCategories()
    }
    
    // MARK: - Private Methods
    
    private func errorMessage(for error: SignRepositoryError) -> String {
        return ErrorMessageMapper.message(for: error)
    }
}

