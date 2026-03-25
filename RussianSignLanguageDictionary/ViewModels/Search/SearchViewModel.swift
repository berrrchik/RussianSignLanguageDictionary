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
    private let hybridSearchServiceBuilder: HybridSearchServiceBuilderProtocol
    private var hybridSearchService: HybridSearchServiceProtocol?
    
    // MARK: - Private Properties
    
    private var allSigns: [Sign] = []
    private var searchableSigns: [SearchableSign] = []
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private(set) var hasLoadedInitialData = false
    
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
            categoryService: container.resolve(CategoryServiceProtocol.self),
            hybridSearchServiceBuilder: container.resolve(HybridSearchServiceBuilderProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(
        signRepository: SignRepositoryProtocol,
        networkMonitor: NetworkMonitorProtocol,
        categoryService: CategoryServiceProtocol,
        hybridSearchServiceBuilder: HybridSearchServiceBuilderProtocol
    ) {
        self.signRepository = signRepository
        self.networkMonitor = networkMonitor
        self.categoryService = categoryService
        self.hybridSearchServiceBuilder = hybridSearchServiceBuilder
        setupDebouncing()
        preloadFromCache()

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
                await executeHybridSearch(trimmedQuery, service: hybridService)
            } else {
                executeLocalSearch(trimmedQuery)
            }
        }
    }
    
    // MARK: - Search Steps
    
    private func executeHybridSearch(_ query: String, service: HybridSearchServiceProtocol) async {
        do {
            let results = try await runHybridSearch(query, service: service)
            guard !Task.isCancelled else { isLoading = false; return }
            applySearchResults(results, query: query, searchType: "hybrid")
        } catch {
            guard !Task.isCancelled else { isLoading = false; return }
            CrashlyticsErrorReporter.capture(error, context: ["query": query], subsystem: "com.rsl.search")
            let textResults = runTextSearchFallback(query, service: service)
            applySearchResults(textResults, query: query, searchType: "text")
        }
    }
    
    private func runHybridSearch(_ query: String, service: HybridSearchServiceProtocol) async throws -> [Sign] {
        try await service.performHybridSearch(
            query: query,
            limit: 50,
            useHighQualityThreshold: false
        )
    }
    
    private func runTextSearchFallback(_ query: String, service: HybridSearchServiceProtocol) -> [Sign] {
        service.performTextSearch(query: query, limit: 50)
    }
    
    private func executeLocalSearch(_ query: String) {
        let lowercasedQuery = query.lowercased()
        let filtered = searchableSigns.filter { $0.lowercasedWord.contains(lowercasedQuery) }
        guard !Task.isCancelled else { isLoading = false; return }
        searchResults = filtered.map { $0.sign }
        isLoading = false
    }
    
    private func applySearchResults(_ results: [Sign], query: String, searchType: String) {
        searchResults = results
        isLoading = false
        AnalyticsService.logSearch(query: query, resultsCount: results.count, searchType: searchType)
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = allSigns
        errorMessage = nil
        searchTask?.cancel()
    }
    
    // MARK: - Computed Properties
    
    var isReady: Bool { hasLoadedInitialData }
    
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

    private func preloadFromCache() {
        guard let cached = signRepository.cachedSigns(), !cached.isEmpty else { return }
        // Обязательно через updateSearchData — иначе hybridSearchService остаётся nil
        // и loadAllSigns() выходит по раннему guard без построения гибридного поиска.
        updateSearchData(with: cached)
        searchResults = cached
        hasLoadedInitialData = true
    }

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
        
        hybridSearchService = hybridSearchServiceBuilder.make(
            signs: signs,
            networkMonitor: networkMonitor
        )
    }
}
