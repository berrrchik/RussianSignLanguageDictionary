import SwiftUI

struct CategoryDetailView: View {
    @StateObject private var viewModel: CategoryDetailViewModel
    
    init(category: Category, signRepository: SignRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: CategoryDetailViewModel(
            category: category,
            signRepository: signRepository
        ))
    }
    
    init(category: Category) {
        let repository = SignRepository()
        _viewModel = StateObject(wrappedValue: CategoryDetailViewModel(
            category: category,
            signRepository: repository
        ))
    }
    
    var body: some View {
        ZStack {
            switch viewModel.state {
            case .idle, .loading:
                LoadingView(message: "Загрузка жестов...")
                
            case .loaded:
                if viewModel.signs.isEmpty {
                    EmptyStateView(
                        icon: "tray.fill",
                        title: "Жесты не найдены",
                        message: "В этой категории пока нет жестов"
                    )
                } else {
                    signsList
                }
                
            case .error(let message):
                ErrorView(message: message) {
                    Task {
                        await viewModel.loadSigns()
                    }
                }
            }
        }
        .navigationTitle(viewModel.category.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel.signs.isEmpty {
                await viewModel.loadSigns()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var signsList: some View {
        List {
            Section {
                ForEach(viewModel.signs) { sign in
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

struct CategoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CategoryDetailView(
                category: Category(id: "alphabet", name: "Алфавит", order: 1, signCount: 33, icon: "textformat.abc", color: nil),
                signRepository: MockSignRepository()
            )
        }
    }
}

private class MockSignRepository: SignRepositoryProtocol {
    func loadAllSigns() async throws -> [Sign] { [] }
    func loadCategories() async throws -> [Category] { [] }
    func getSign(byId id: String) async throws -> Sign? { nil }
    
    func getSigns(byCategory categoryId: String) async throws -> [Sign] {
        [
            Sign(
                id: "sign_001",
                word: "Привет",
                description: "Жест приветствия",
                category: "alphabet",
                videoId: "video_001",
                supabaseStoragePath: "test/path.mp4",
                supabaseUrl: "https://example.com/video.mp4",
                keywords: ["привет"],
                embeddings: [],
                metadata: SignMetadata(duration: 3.0, fileSize: 500000, resolution: "1080x1920", format: "mp4", fps: 30)
            ),
            Sign(
                id: "sign_002",
                word: "Спасибо",
                description: "Жест благодарности",
                category: "alphabet",
                videoId: "video_002",
                supabaseStoragePath: "test/path2.mp4",
                supabaseUrl: "https://example.com/video2.mp4",
                keywords: ["спасибо"],
                embeddings: [],
                metadata: SignMetadata(duration: 3.0, fileSize: 500000, resolution: "1080x1920", format: "mp4", fps: 30)
            )
        ]
    }
    
    func searchSigns(query: String) async throws -> [Sign] { [] }
}

