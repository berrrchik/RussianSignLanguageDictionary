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
        
        isLoading = true
        errorMessage = nil
        isOfflineMode = false
        offlineMessage = nil
        
        do {
            let signs = try await signRepository.loadAllSigns()
            updateSearchData(with: signs)
            hasLoadedInitialData = true
            
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
            }
        } catch {
            errorMessage = errorMessage(for: error)
            isLoading = false
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
                } catch {
                    guard !Task.isCancelled else {
                        self.isLoading = false
                        return
                    }
                    
                    let textResults = hybridService.performTextSearch(
                        query: trimmedQuery,
                        limit: 50
                    )
                    self.searchResults = textResults
                    self.isLoading = false
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
