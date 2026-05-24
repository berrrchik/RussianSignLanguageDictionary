import Foundation
import os.log

// MARK: - Outcome

/// Результат офлайн-подготовки видео для жеста
enum OfflinePreparationOutcome {
    /// Все видео успешно скачаны — жест готов к офлайн-просмотру
    case readyOffline
    /// Одно из видео не удалось скачать
    case failed
    /// Задача отменена или жест был удалён из избранного во время подготовки
    case cancelled
}

// MARK: - Protocol

/// Протокол сервиса для скачивания видео избранных жестов в долгосрочный кеш.
///
/// Инкапсулирует единственный алгоритм офлайн-подготовки, который ранее дублировался
/// в `FavoritesViewModel` и `SignDetailViewModel`.
@MainActor
protocol OfflinePreparationServiceProtocol {
    /// Скачивает все видео жеста в долгосрочный кеш и обновляет статус в `FavoritesRepository`.
    ///
    /// - Parameters:
    ///   - sign: Жест для подготовки
    ///   - categoryName: Название категории (сохраняется в snapshot)
    /// - Returns: Итог подготовки
    func prepare(sign: Sign, categoryName: String) async -> OfflinePreparationOutcome
}

// MARK: - Implementation

/// Сервис офлайн-подготовки видео избранных жестов.
///
/// Итерирует по `sign.videosArray`, скачивает каждое видео через `VideoRepository`
/// с `useFavoritesCache: true` и обновляет `FavoritesRepository` на каждом этапе.
/// При отмене `Task` или удалении жеста из избранного — завершается без изменения статуса.
@MainActor
final class OfflinePreparationService: OfflinePreparationServiceProtocol {

    // MARK: - Properties

    private let videoRepository: VideoRepositoryProtocol
    private let favoritesRepository: FavoritesRepositoryProtocol
    private let logger = Logger(subsystem: "com.rsl.offline", category: "OfflinePreparationService")

    // MARK: - Init

    init(
        videoRepository: VideoRepositoryProtocol,
        favoritesRepository: FavoritesRepositoryProtocol
    ) {
        self.videoRepository = videoRepository
        self.favoritesRepository = favoritesRepository
    }

    // MARK: - OfflinePreparationServiceProtocol

    func prepare(sign: Sign, categoryName: String) async -> OfflinePreparationOutcome {
        guard favoritesRepository.isFavorite(signId: sign.id) else {
            logger.debug("⏭️ Жест \(sign.id) уже не в избранном — пропускаем подготовку")
            return .cancelled
        }

        let requiredVideoIds = sign.videosArray.map(\.id)
        favoritesRepository.updateFavoriteSnapshot(sign: sign, categoryName: categoryName)

        guard !requiredVideoIds.isEmpty else {
            favoritesRepository.updateOfflineStatus(
                signId: sign.id,
                status: .readyOffline,
                downloadedVideoIds: [],
                requiredVideoIds: []
            )
            return .readyOffline
        }

        var downloadedVideoIds: [Int] = []

        for video in sign.videosArray {
            guard !Task.isCancelled else {
                logger.debug("🚫 Подготовка \(sign.id) отменена")
                return .cancelled
            }

            do {
                _ = try await videoRepository.getVideoURL(for: video, useFavoritesCache: true)
                downloadedVideoIds.append(video.id)
            } catch {
                guard favoritesRepository.isFavorite(signId: sign.id) else { return .cancelled }

                favoritesRepository.updateOfflineStatus(
                    signId: sign.id,
                    status: .failed,
                    downloadedVideoIds: downloadedVideoIds,
                    requiredVideoIds: requiredVideoIds
                )
                logger.warning("⚠️ Не удалось подготовить офлайн-видео для \(sign.id): \(error.localizedDescription)")
                return .failed
            }
        }

        guard favoritesRepository.isFavorite(signId: sign.id) else { return .cancelled }

        favoritesRepository.updateOfflineStatus(
            signId: sign.id,
            status: .readyOffline,
            downloadedVideoIds: downloadedVideoIds,
            requiredVideoIds: requiredVideoIds
        )
        logger.info("✅ Жест \(sign.id) готов к офлайн-просмотру")
        return .readyOffline
    }
}
