import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
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
    
    // Фильтрация и сортировка
    @Published var selectedCategoryId: String? = nil
    @Published var sortOrder: SortOrder = .ascending
    
    // MARK: - Dependencies
    
    private let signRepository: SignRepositoryProtocol
    private let networkMonitor: NetworkMonitorProtocol
    private var hybridSearchService: HybridSearchService?
    
    // MARK: - Private Properties
    
    private var allSigns: [Sign] = [] 
    private var searchableSigns: [SearchableSign] = [] 
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
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
        let lowercasedKeywords: [String]
    }
    
    // MARK: - Init
    
    init(
        signRepository: SignRepositoryProtocol,
        networkMonitor: NetworkMonitorProtocol = NetworkMonitor()
    ) {
        self.signRepository = signRepository
        self.networkMonitor = networkMonitor
        setupDebouncing()
    }
    
    // MARK: - Public Methods
    
    func loadAllSigns() async {
        guard allSigns.isEmpty else {
            searchResults = allSigns
            return
        }
        
        isLoading = true
        errorMessage = nil
        isOfflineMode = false
        offlineMessage = nil
        
        do {
            let signs = try await signRepository.loadAllSigns()
            allSigns = signs
            searchResults = signs
            

            searchableSigns = signs.map { sign in
                SearchableSign(
                    sign: sign,
                    lowercasedWord: sign.word.lowercased(),
                    lowercasedKeywords: (sign.keywords ?? []).map { $0.lowercased() }
                )
            }
            
            // Инициализация гибридного сервиса поиска
            hybridSearchService = HybridSearchService(
                baseURL: APIConfig.baseURL,
                signs: signs,
                networkMonitor: networkMonitor
            )
            
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
            
            // Используем гибридный поиск, если доступен
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
                    // При ошибке SBERT поиска используем текстовый поиск как fallback
                    guard !Task.isCancelled else {
                        self.isLoading = false
                        return
                    }
                    
                    // Fallback на текстовый поиск
                    let textResults = hybridService.performTextSearch(
                        query: trimmedQuery,
                        limit: 50
                    )
                    self.searchResults = textResults
                    self.isLoading = false
                    
                    // Не показываем ошибку пользователю, так как fallback работает
                    // Логируем для отладки
                    if let sbertError = error as? SBERTSearchError {
                        // Только для критических ошибок показываем сообщение
                        if case .serverError(let code, _) = sbertError,
                           code == "SEARCH_ERROR" {
                            // Модель не загружена - это нормально, используем текстовый поиск
                        }
                    }
                }
            } else {
                // Fallback на старый текстовый поиск, если гибридный сервис не инициализирован
                let lowercasedQuery = trimmedQuery.lowercased()
                
                let filtered = searchableSigns.filter { searchable in
                    searchable.lowercasedWord.contains(lowercasedQuery) ||
                    searchable.lowercasedKeywords.contains(where: { $0.contains(lowercasedQuery) })
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
        CategoryService.allCategories()
    }
    
    var groupedResults: [SignSection] {
        var filtered = searchResults
        
        if let categoryId = selectedCategoryId {
            filtered = filtered.filter { $0.categoryId == categoryId }
        }
        
        // Если есть активный поиск - показываем результаты по релевантности (без алфавитной группировки)
        // Если поиска нет - показываем по алфавиту
        let isSearchActive = !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        if isSearchActive {
            // При активном поиске: одна секция с результатами в порядке релевантности
            // Порядок уже правильный: точные совпадения → SBERT (по similarity) → текстовые
            return [SignSection(id: "search_results", letter: "", signs: filtered)]
        } else {
            // Без поиска: алфавитная группировка
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
}

