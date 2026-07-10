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
        /// Максимальная длина поискового запроса, передаваемого в SBERT.
        /// Защищает от неожиданно долгих запросов при вставке большого текста.
        static let maxSearchQueryLength: Int = 100
    }
    
    // MARK: - Published Properties
    
    @Published var searchQuery: String = ""
    @Published private(set) var searchResults: [Sign] = []
    @Published private(set) var categories: [Category] = []
    @Published private(set) var categoryNamesById: [String: String] = [:]
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published var selectedCategoryId: String? = nil
    @Published var sortOrder: SortOrder = .ascending
    
    // MARK: - Dependencies
    
    private let signRepository: SignRepositoryProtocol
    private let searchCoordinator: SearchCoordinator
    
    // MARK: - Private Properties
    
    private var allSigns: [Sign] = []
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
    
    // MARK: - Init
    
    /// Convenience init для production — резолвит зависимости из DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            signRepository: container.resolve(SignRepositoryProtocol.self),
            networkMonitor: container.resolve(NetworkMonitorProtocol.self),
            hybridSearchServiceBuilder: container.resolve(HybridSearchServiceBuilderProtocol.self)
        )
    }
    
    /// Полный init для тестов и preview (constructor injection)
    init(
        signRepository: SignRepositoryProtocol,
        networkMonitor: NetworkMonitorProtocol,
        hybridSearchServiceBuilder: HybridSearchServiceBuilderProtocol
    ) {
        self.signRepository = signRepository
        self.searchCoordinator = SearchCoordinator(
            networkMonitor: networkMonitor,
            hybridSearchServiceBuilder: hybridSearchServiceBuilder
        )
        setupDebouncing()
        preloadFromCache()
        signRepository.dataUpdatedPublisher
            .sink { [weak self] updatedData in
                Task { @MainActor [weak self] in
                    self?.handleUpdatedData(updatedData)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadAllSigns() async {
        let hasActiveSearch = !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let needsInitialLoad = !hasLoadedInitialData || allSigns.isEmpty || categories.isEmpty
        
        guard needsInitialLoad else {
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
        
        do {
            async let loadedSignsTask = signRepository.loadAllSigns()
            async let loadedCategoriesTask = signRepository.loadCategories()
            let (signs, loadedCategories) = try await (loadedSignsTask, loadedCategoriesTask)

            applyLoadedData(signs: signs, categories: loadedCategories)
            hasLoadedInitialData = true
            
            PerformanceService.incrementMetric(trace, name: "signs_loaded", by: Int64(signs.count))
            
            if hasActiveSearch {
                await performSearch(query: searchQuery)
            } else {
                searchResults = signs
            }
            
            isLoading = false
        } catch {
            errorMessage = errorMessage(for: error)
            isLoading = false
            PerformanceService.addAttribute(trace, name: "error", value: error.localizedDescription)
        }
    }
    
    func performSearch(query: String) async {
        searchTask?.cancel()
        isLoading = false
        
        let trimmedQuery = String(
            query.trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(Constants.maxSearchQueryLength)
        )
        guard !trimmedQuery.isEmpty else {
            searchResults = allSigns
            return
        }
        
        searchTask = Task {
            isLoading = true
            errorMessage = nil

            guard let outcome = await searchCoordinator.performSearch(query: trimmedQuery) else {
                isLoading = false
                return
            }

            applySearchOutcome(outcome, query: trimmedQuery)
        }
    }

    private func applySearchOutcome(_ outcome: SearchCoordinator.SearchOutcome, query: String) {
        searchResults = outcome.results
        isLoading = false

        if let analyticsSearchType = outcome.analyticsSearchType {
            AnalyticsService.logSearch(
                query: query,
                resultsCount: outcome.results.count,
                searchType: analyticsSearchType
            )
        }
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = allSigns
        errorMessage = nil
        searchTask?.cancel()
    }
    
    // MARK: - Computed Properties
    
    var isReady: Bool { hasLoadedInitialData }
    
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
        if let cachedData = signRepository.cachedData(), !cachedData.signs.isEmpty {
            applyLoadedData(signs: cachedData.signs, categories: cachedData.categories)
            searchResults = cachedData.signs
            hasLoadedInitialData = true
            return
        }

        guard let cached = signRepository.cachedSigns(), !cached.isEmpty else { return }
        // Обязательно через updateSearchData — иначе coordinator не построит
        // hybrid-поиск, а loadAllSigns() выйдет по раннему guard.
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

    private func applyLoadedData(signs: [Sign], categories: [Category]) {
        updateSearchData(with: signs)
        self.categories = CategoryDisplayDataHelper.sortedCategories(categories)
        categoryNamesById = CategoryDisplayDataHelper.categoryNamesById(from: self.categories)
    }

    private func handleUpdatedData(_ updatedData: SyncData) {
        applyLoadedData(signs: updatedData.signs, categories: updatedData.categories)

        if !searchQuery.isEmpty {
            Task { @MainActor in
                await performSearch(query: searchQuery)
            }
        } else {
            searchResults = allSigns
        }

        logger.info("🔄 UI обновлён (\(self.allSigns.count) жестов, \(self.categories.count) категорий)")
    }
    
    private func errorMessage(for error: Error) -> String {
        return ErrorMessageMapper.message(for: error)
    }
    
    /// Обновляет данные поиска при загрузке/перезагрузке жестов
    /// - Parameter signs: Массив жестов для индексации
    private func updateSearchData(with signs: [Sign]) {
        allSigns = signs
        searchCoordinator.updateSearchData(with: signs)
    }
}
