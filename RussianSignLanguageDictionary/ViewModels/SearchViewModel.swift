import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var searchQuery: String = ""
    @Published private(set) var searchResults: [Sign] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let signRepository: SignRepositoryProtocol
    
    // MARK: - Private Properties
    
    private var allSigns: [Sign] = [] 
    private var searchableSigns: [SearchableSign] = [] 
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Helper Structures
    
    private struct SearchableSign {
        let sign: Sign
        let lowercasedWord: String
        let lowercasedKeywords: [String]
    }
    
    // MARK: - Init
    
    init(signRepository: SignRepositoryProtocol) {
        self.signRepository = signRepository
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
        
        do {
            let signs = try await signRepository.loadAllSigns()
            allSigns = signs
            searchResults = signs
            

            searchableSigns = signs.map { sign in
                SearchableSign(
                    sign: sign,
                    lowercasedWord: sign.word.lowercased(),
                    lowercasedKeywords: sign.keywords.map { $0.lowercased() }
                )
            }
            
            isLoading = false
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
    
    func clearSearch() {
        searchQuery = ""
        searchResults = allSigns
        errorMessage = nil
        searchTask?.cancel()
    }
    
    // MARK: - Private Methods
    
    private func setupDebouncing() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
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

