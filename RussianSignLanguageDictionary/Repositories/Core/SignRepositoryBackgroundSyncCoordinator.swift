import Foundation
import os.log

/// Actor для дедупликации фоновых синхронизаций `SignRepository`.
/// Гарантирует, что одновременно выполняется не более одной фоновой задачи синхронизации,
/// даже при параллельных вызовах из нескольких ViewModel.
actor SignRepositoryBackgroundSyncCoordinator {

    private var activeTask: Task<Void, Never>?
    private var generation = 0
    private let logger: Logger

    init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    deinit {
        activeTask?.cancel()
    }

    /// Запускает фоновую работу, если предыдущая ещё не выполняется.
    func scheduleIfNeeded(perform work: @escaping @Sendable () async -> Void) {
        guard activeTask == nil || activeTask?.isCancelled == true else {
            logger.debug("⏭️ Фоновая синхронизация уже запущена")
            return
        }

        generation += 1
        let scheduledGeneration = generation
        activeTask = Task { [weak self] in
            await work()
            await self?.clearTask(generation: scheduledGeneration)
        }
    }

    /// Обнуляет `activeTask`, только если он всё ещё относится к тому же "поколению"
    /// планирования. Без этой проверки отменённая-но-ещё-не-завершённая задача могла бы
    /// затереть ссылку на новую задачу, запущенную после неё (cancel-then-reschedule гонка).
    /// Используем номер поколения (Int), а не саму `Task`, чтобы не захватывать
    /// изменяемую `var` в замыкании до её инициализации — иначе замыкание не-Sendable.
    private func clearTask(generation finishedGeneration: Int) {
        guard finishedGeneration == generation else { return }
        activeTask = nil
    }
}
