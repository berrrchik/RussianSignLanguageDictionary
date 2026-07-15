import Foundation
import os.log

/// Отвечает за повторные попытки офлайн-подготовки видео для избранных жестов,
/// у которых предыдущая подготовка не удалась или не завершилась. Выделен из
/// `FavoritesViewModel`, чтобы отделить эту зону ответственности от загрузки/CRUD избранного.
///
/// Не хранит собственное UI-состояние — сообщает об изменениях через колбэки,
/// вызываемые вызывающей стороной (`FavoritesViewModel`) на её `@Published`-свойствах.
@MainActor
final class FavoritesOfflineRetryCoordinator {
    private let logger = Logger(subsystem: "com.rsl.favorites", category: "OfflineRetry")

    private let favoritesRepository: FavoritesRepositoryProtocol
    private let signRepository: SignRepositoryProtocol
    private let offlinePreparationService: OfflinePreparationServiceProtocol
    private let networkMonitor: NetworkMonitorProtocol

    private var retryTask: Task<Void, Never>?

    init(
        favoritesRepository: FavoritesRepositoryProtocol,
        signRepository: SignRepositoryProtocol,
        offlinePreparationService: OfflinePreparationServiceProtocol,
        networkMonitor: NetworkMonitorProtocol
    ) {
        self.favoritesRepository = favoritesRepository
        self.signRepository = signRepository
        self.offlinePreparationService = offlinePreparationService
        self.networkMonitor = networkMonitor
    }

    deinit {
        retryTask?.cancel()
    }

    func cancel() {
        retryTask?.cancel()
        retryTask = nil
    }

    /// Запускает повтор только если есть жесты, требующие повторной офлайн-подготовки.
    func scheduleRetryIfNeeded(
        categoryName: @escaping (String) -> String,
        onStatusUpdate: @escaping (String, FavoriteOfflineStatus) -> Void,
        onAllResolved: @escaping () -> Void
    ) {
        guard !retryableEntries().isEmpty else { return }
        retryNow(categoryName: categoryName, onStatusUpdate: onStatusUpdate, onAllResolved: onAllResolved)
    }

    /// Безусловно запускает (перезапускает) повтор офлайн-подготовки.
    func retryNow(
        categoryName: @escaping (String) -> String,
        onStatusUpdate: @escaping (String, FavoriteOfflineStatus) -> Void,
        onAllResolved: @escaping () -> Void
    ) {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            await self?.performRetry(
                categoryName: categoryName,
                onStatusUpdate: onStatusUpdate,
                onAllResolved: onAllResolved
            )
        }
    }

    private func performRetry(
        categoryName: (String) -> String,
        onStatusUpdate: (String, FavoriteOfflineStatus) -> Void,
        onAllResolved: () -> Void
    ) async {
        guard await networkMonitor.checkConnection() else { return }

        await favoritesRepository.reconcileOfflineState()
        let failedEntries = retryableEntries()

        guard !failedEntries.isEmpty else { return }

        for entry in failedEntries {
            guard !Task.isCancelled else { return }
            guard favoritesRepository.isFavorite(signId: entry.signId) else { continue }

            if let snapshot = favoritesRepository.cachedFavoriteSnapshot(signId: entry.signId) {
                await prepareOfflineMedia(for: snapshot.sign, categoryName: snapshot.categoryName, onStatusUpdate: onStatusUpdate)
                continue
            }

            do {
                guard let liveSign = try await signRepository.getSign(byId: entry.signId) else { continue }
                let resolvedCategoryName = categoryName(liveSign.categoryId)
                favoritesRepository.updateFavoriteSnapshot(sign: liveSign, categoryName: resolvedCategoryName)
                await prepareOfflineMedia(for: liveSign, categoryName: resolvedCategoryName, onStatusUpdate: onStatusUpdate)
            } catch {
                logger.warning("⚠️ Не удалось восстановить snapshot для retry \(entry.signId): \(error.localizedDescription)")
            }
        }

        if retryableEntries().isEmpty {
            onAllResolved()
        }
    }

    private func retryableEntries() -> [FavoriteEntry] {
        favoritesRepository.getFavoriteEntries().filter { entry in
            switch entry.offlineStatus {
            case .failed:
                return true
            case .pending:
                return !entry.requiredVideoIds.isEmpty
            case .readyOffline:
                return false
            }
        }
    }

    private func prepareOfflineMedia(
        for sign: Sign,
        categoryName: String,
        onStatusUpdate: (String, FavoriteOfflineStatus) -> Void
    ) async {
        let outcome = await offlinePreparationService.prepare(sign: sign, categoryName: categoryName)
        switch outcome {
        case .readyOffline:
            onStatusUpdate(sign.id, .readyOffline)
        case .failed:
            onStatusUpdate(sign.id, .failed)
        case .cancelled:
            break
        }
    }
}
