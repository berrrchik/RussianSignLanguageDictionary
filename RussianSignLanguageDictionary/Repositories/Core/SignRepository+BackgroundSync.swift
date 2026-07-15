import Foundation

// MARK: - Background Sync

extension SignRepository {

    func scheduleBackgroundSyncIfNeeded() async {
        await backgroundSyncCoordinator.scheduleIfNeeded { [weak self] in
            await self?.performBackgroundSync()
        }
    }

    private func performBackgroundSync() async {
        guard !Task.isCancelled else {
            logger.debug("🛑 Фоновая синхронизация отменена до старта")
            return
        }

        guard await networkMonitor.checkConnection() else {
            logger.debug("📴 Нет интернета для фоновой синхронизации")
            updateDataStatus(.usingCachedData(.noInternet))
            return
        }

        do {
            logger.info("🔄 Фоновая синхронизация...")

            let currentData = memoryCache.get()
            let syncData = try await syncRepository.fetchAllData { [weak self] in
                guard let cached = self?.memoryCache.get() else {
                    throw SignRepositoryError.noDataAvailable
                }
                return cached
            }

            guard !Task.isCancelled else {
                logger.debug("🛑 Фоновая синхронизация отменена после загрузки")
                return
            }

            guard currentData?.lastUpdated != syncData.lastUpdated else {
                logger.info("ℹ️ Данные не изменились")
                updateDataStatus(.upToDate)
                return
            }

            logger.info("🆕 Обнаружены изменения!")
            saveToAllCaches(syncData)
            dataUpdatedSubject.send(syncData)
            updateDataStatus(.updated)
            logger.info("✅ Фоновая синхронизация завершена с обновлением UI")

        } catch {
            if error is CancellationError {
                logger.debug("🛑 Фоновая синхронизация отменена")
                return
            }
            updateDataStatus(.usingCachedData(await dataStatusReason(for: error)))
            logger.warning("⚠️ Фоновая синхронизация не удалась: \(error.localizedDescription)")
        }
    }
}
