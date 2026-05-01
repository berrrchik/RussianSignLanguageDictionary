import XCTest
@testable import RussianSignLanguageDictionary

@MainActor
final class CategoriesViewModelTests: XCTestCase {
    private var sut: CategoriesViewModel!
    private var signRepository: SignRepositorySpy!

    override func setUp() {
        super.setUp()
        signRepository = SignRepositorySpy()
        sut = CategoriesViewModel(signRepository: signRepository)
    }

    override func tearDown() {
        sut = nil
        signRepository = nil
        super.tearDown()
    }

    func testInitialStateIsIdle() {
        XCTAssertEqual(sut.categories, [])
        XCTAssertEqual(sut.state, .idle)
    }

    func testLoadCategoriesTransitionsToLoadedAndSortsByOrder() async {
        signRepository.loadCategoriesResult = .success([
            makeCategory(id: "2", name: "Животные", order: 2),
            makeCategory(id: "1", name: "Алфавит", order: 1)
        ])

        await sut.loadCategories()

        XCTAssertEqual(signRepository.loadCategoriesCallCount, 1)
        XCTAssertEqual(sut.categories.map(\.id), ["1", "2"])
        XCTAssertEqual(sut.state, .loaded)
    }

    func testLoadCategoriesPublishesLoadingStateBeforeCompleting() async {
        let started = expectation(description: "loadCategories started")
        var continuation: CheckedContinuation<[AppCategory], Never>?

        signRepository.loadCategoriesImplementation = {
            started.fulfill()
            return await withCheckedContinuation { checkedContinuation in
                continuation = checkedContinuation
            }
        }

        let task = Task { await self.sut.loadCategories() }

        await fulfillment(of: [started], timeout: 1.0)
        XCTAssertEqual(sut.state, .loading)

        continuation?.resume(returning: [makeCategory(id: "1", name: "Алфавит", order: 1)])
        await task.value
        XCTAssertEqual(sut.state, .loaded)
    }

    func testLoadCategoriesMapsRepositoryErrors() async {
        signRepository.loadCategoriesResult = .failure(SignRepositoryError.fileNotFound)

        await sut.loadCategories()

        XCTAssertEqual(sut.categories, [])
        XCTAssertEqual(sut.state, .error("Не удалось загрузить данные"))
    }

    func testLoadCategoriesFallsBackToUnknownErrorMessage() async {
        signRepository.loadCategoriesResult = .failure(NSError(domain: "test", code: 7))

        await sut.loadCategories()

        if case .error(let message) = sut.state {
            XCTAssertTrue(message.hasPrefix("Произошла ошибка:"))
        } else {
            XCTFail("Expected error state")
        }
    }

    func testRefreshCategoriesReloadsData() async {
        signRepository.loadCategoriesResult = .success([makeCategory(id: "1", name: "Алфавит", order: 1)])

        await sut.refreshCategories()

        XCTAssertEqual(signRepository.loadCategoriesCallCount, 1)
        XCTAssertEqual(sut.state, .loaded)
    }

    func testRepositoryUpdatesReplaceCategoriesUsingSnapshotOrder() async {
        signRepository.dataUpdatedSubject.send(
            SyncData(
                categories: [
                    makeCategory(id: "2", name: "Животные", order: 2),
                    makeCategory(id: "1", name: "Алфавит", order: 1)
                ],
                signs: [],
                lessons: [],
                lastUpdated: Date()
            )
        )

        let didUpdate = await waitUntil {
            self.sut.categories.map(\.id) == ["1", "2"]
        }

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(sut.categories.map(\.id), ["1", "2"])
        XCTAssertEqual(sut.state, .loaded)
    }

    private func makeCategory(id: String, name: String, order: Int) -> AppCategory {
        AppCategory(
            id: id,
            name: name,
            order: order,
            signCount: 1,
            icon: nil,
            color: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollInterval: UInt64 = 20_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return true
            }

            try? await Task.sleep(nanoseconds: pollInterval)
        }

        return condition()
    }
}
