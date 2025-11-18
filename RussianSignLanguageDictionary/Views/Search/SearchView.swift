import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @State private var isSearching = false
    
    init(signRepository: SignRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: SearchViewModel(signRepository: signRepository))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    LoadingView(message: viewModel.searchQuery.isEmpty ? "Загрузка жестов..." : "Поиск...")
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        Task {
                            await viewModel.loadAllSigns()
                        }
                    }
                } else if viewModel.searchResults.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: viewModel.searchQuery.isEmpty ? "Нет данных" : "Ничего не найдено",
                        message: viewModel.searchQuery.isEmpty ? "Данные о жестах не загружены" : "Попробуйте изменить запрос"
                    )
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("Поиск")
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Введите слово для поиска"
            )
            .task {
                await viewModel.loadAllSigns()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var searchResultsList: some View {
        List {
            Section {
                ForEach(viewModel.searchResults) { sign in
                    NavigationLink(destination: SignDetailView(sign: sign)) {
                        SignRowView(sign: sign)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(signRepository: MockSignRepository())
    }
}

// MARK: - Mock for Preview

private class MockSignRepository: SignRepositoryProtocol {
    func loadAllSigns() async throws -> [Sign] { [] }
    func loadCategories() async throws -> [Category] { [] }
    func getSign(byId id: String) async throws -> Sign? { nil }
    func getSigns(byCategory categoryId: String) async throws -> [Sign] { [] }
    func searchSigns(query: String) async throws -> [Sign] {
        [
            Sign(
                id: "sign_001",
                word: "Привет",
                description: "Жест приветствия",
                category: "greetings",
                videoId: "video_001",
                supabaseStoragePath: "test/path.mp4",
                supabaseUrl: "https://example.com/video.mp4",
                keywords: ["привет"],
                embeddings: [],
                metadata: SignMetadata(duration: 3.0, fileSize: 500000, resolution: "1080x1920", format: "mp4", fps: 30)
            ),
            Sign(
                id: "sign_002",
                word: "Здравствуй",
                description: "Жест приветствия",
                category: "greetings",
                videoId: "video_002",
                supabaseStoragePath: "test/path2.mp4",
                supabaseUrl: "https://example.com/video2.mp4",
                keywords: ["здравствуй"],
                embeddings: [],
                metadata: SignMetadata(duration: 3.0, fileSize: 500000, resolution: "1080x1920", format: "mp4", fps: 30)
            )
        ]
    }
}

