import Foundation
import Combine
import os.log

@MainActor
final class SearchViewModel: ObservableObject {
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.rsl.search", category: "SearchViewModel")
    // MARK: - Constants
    
    private enum Constants {
        static let debounceMilliseconds: Int = 300
    }
    
    // MARK: - Published Properties
    
    @Published var searchQuery: String = ""
    @Published private(set) var searchResults: [Sign] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isOfflineMode: Bool = false
    @Published private(set) var offlineMessage: String?
    @Published var selectedCategoryId: String? = nil
    @Published var sortOrder: SortOrder = .ascending
    
    // MARK: - Dependencies
    
    private let signRepository: SignRepositoryProtocol
    private let networkMonitor: NetworkMonitorProtocol
    private let categoryService: CategoryServiceProtocol
    private var hybridSearchService: HybridSearchService?
    
    // MARK: - Private Properties
    
    private var allSigns: [Sign] = []
    private var searchableSigns: [SearchableSign] = []
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedInitialData = false
    
    // MARK: - Enums
    
    enum SortOrder {
        case ascending
        case descending
    }
    
    // MARK: - Helper Structures
    
    struct SignSection: Identifiable {
        let id: String
        let letter: String
        let signs: [Sign]
    }
    
    private struct SearchableSign {
        let sign: Sign
        let lowercasedWord: String
    }
    
    // MARK: - Init
    
    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            signRepository: container.resolve(SignRepositoryProtocol.self),
            networkMonitor: container.resolve(NetworkMonitorProtocol.self),
            categoryService: container.resolve(CategoryServiceProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(
        signRepository: SignRepositoryProtocol,
        networkMonitor: NetworkMonitorProtocol,
        categoryService: CategoryServiceProtocol
    ) {
        self.signRepository = signRepository
        self.networkMonitor = networkMonitor
        self.categoryService = categoryService
        setupDebouncing()
        
        NotificationCenter.default.publisher(for: .signsDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadSigns()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadAllSigns() async {
        let hasActiveSearch = !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        guard !hasLoadedInitialData || allSigns.isEmpty else {
            if hasActiveSearch {
                return
            }
            searchResults = allSigns
            return
        }
        
        let trace = PerformanceService.startTrace("screen_search_load")
        defer { PerformanceService.stopTrace(trace) }
        
        isLoading = true
        errorMessage = nil
        isOfflineMode = false
        offlineMessage = nil
        
        do {
            let signs = try await signRepository.loadAllSigns()
            updateSearchData(with: signs)
            hasLoadedInitialData = true
            
            PerformanceService.incrementMetric(trace, name: "signs_loaded", by: Int64(signs.count))
            
            if hasActiveSearch {
                await performSearch(query: searchQuery)
            } else {
                searchResults = signs
            }
            
            isLoading = false
            let isConnected = await networkMonitor.checkConnection()
            if !isConnected {
                isOfflineMode = true
                offlineMessage = "Работа в офлайн-режиме. Показаны сохранённые данные."
                PerformanceService.addAttribute(trace, name: "offline_mode", value: "true")
            }
        } catch {
            errorMessage = errorMessage(for: error)
            isLoading = false
            PerformanceService.addAttribute(trace, name: "error", value: error.localizedDescription)
        }
    }
    
    private func reloadSigns() {
        Task { @MainActor in
            do {
                let signs = try await signRepository.loadAllSigns()
                updateSearchData(with: signs)
                
                if !searchQuery.isEmpty {
                    await performSearch(query: searchQuery)
                } else {
                    searchResults = signs
                }
                
                logger.info("🔄 UI обновлён (\(signs.count) жестов)")
            } catch {
                logger.warning("⚠️ Не удалось обновить UI: \(error.localizedDescription)")
            }
        }
    }
    
    func performSearch(query: String) async {
        searchTask?.cancel()
        isLoading = false
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchResults = allSigns
            return
        }
        
        searchTask = Task {
            isLoading = true
            errorMessage = nil
            
            if let hybridService = hybridSearchService {
                do {
                    let results = try await hybridService.performHybridSearch(
                        query: trimmedQuery,
                        limit: 50
                    )
                    
                    guard !Task.isCancelled else {
                        self.isLoading = false
                        return
                    }
                    
                    self.searchResults = results
                    self.isLoading = false
                    
                    // Логируем успешный поиск в аналитику
                    AnalyticsService.logSearch(
                        query: trimmedQuery,
                        resultsCount: results.count,
                        searchType: "hybrid"
                    )
                } catch {
                    guard !Task.isCancelled else {
                        self.isLoading = false
                        return
                    }
                    
                    // CrashlyticsErrorReporter.isExpectedError() уже фильтрует ожидаемые ошибки:
                    // - SBERTSearchError.httpError с 4xx → не отправляется
                    // - SBERTSearchError.serverError и unknown → отправляются (критические)
                    CrashlyticsErrorReporter.capture(error, context: ["query": trimmedQuery], subsystem: "com.rsl.search")
                    
                    let textResults = hybridService.performTextSearch(
                        query: trimmedQuery,
                        limit: 50
                    )
                    self.searchResults = textResults
                    self.isLoading = false
                    
                    // Логируем fallback на текстовый поиск
                    AnalyticsService.logSearch(
                        query: trimmedQuery,
                        resultsCount: textResults.count,
                        searchType: "text"
                    )
                }
            } else {
                let lowercasedQuery = trimmedQuery.lowercased()
                
                let filtered = searchableSigns.filter { searchable in
                    searchable.lowercasedWord.contains(lowercasedQuery)
                }
                
                guard !Task.isCancelled else {
                    self.isLoading = false
                    return
                }
                
                self.searchResults = filtered.map { $0.sign }
                self.isLoading = false
            }
        }
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = allSigns
        errorMessage = nil
        searchTask?.cancel()
    }
    
    // MARK: - Computed Properties
    
    var categories: [Category] {
        categoryService.allCategories()
    }
    
    var groupedResults: [SignSection] {
        var filtered = searchResults
        
        if let categoryId = selectedCategoryId {
            filtered = filtered.filter { $0.categoryId == categoryId }
        }
        
        let isSearchActive = !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        if isSearchActive {
            return [SignSection(id: "search_results", letter: "", signs: filtered)]
        } else {
            return SignGroupingHelper.groupByFirstLetter(filtered, sortOrder: sortOrder)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDebouncing() {
        $searchQuery
            .debounce(for: .milliseconds(Constants.debounceMilliseconds), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }
    
    private func errorMessage(for error: Error) -> String {
        return ErrorMessageMapper.message(for: error)
    }
    
    /// Обновляет данные поиска при загрузке/перезагрузке жестов
    /// - Parameter signs: Массив жестов для индексации
    private func updateSearchData(with signs: [Sign]) {
        allSigns = signs
        
        searchableSigns = signs.map { sign in
            SearchableSign(
                sign: sign,
                lowercasedWord: sign.word.lowercased()
            )
        }
        
        hybridSearchService = HybridSearchService(
            baseURL: APIConfig.baseURL,
            signs: signs,
            networkMonitor: networkMonitor,
            sbertService: SBERTSearchService(baseURL: APIConfig.baseURL)
        )
    }
}
