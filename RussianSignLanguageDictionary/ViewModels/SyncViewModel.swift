import Foundation
import SwiftUI

/// ViewModel для управления синхронизацией данных
@MainActor
final class SyncViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Флаг выполнения синхронизации
    @Published var isSyncing = false
    
    /// Дата последней синхронизации
    @Published var lastSyncDate: Date?
    
    /// Ошибка синхронизации (если есть)
    @Published var syncError: String?
    
    // MARK: - Private Properties
    
    private let syncRepository: SyncRepositoryProtocol
    private let cacheService: CacheService
    
    // MARK: - Initialization
    
    init(
        syncRepository: SyncRepositoryProtocol,
        cacheService: CacheService
    ) {
        self.syncRepository = syncRepository
        self.cacheService = cacheService
        
        // Загружаем дату последней синхронизации из кеша
        loadLastSyncDate()
    }
    
    // MARK: - Methods
    
    /// Выполняет синхронизацию данных
    func sync() async {
        isSyncing = true
        syncError = nil
        
        do {
            // Проверяем наличие обновлений
            let metadata = try await syncRepository.checkForUpdates(lastUpdated: lastSyncDate)
            
            if metadata.hasUpdates {
                print("🔄 SyncViewModel: Обнаружены обновления, загрузка данных...")
                
                // Загружаем все данные
                let data = try await syncRepository.fetchAllData()
                
                // Сохраняем в кеш
                try cacheService.save(data)
                
                // Обновляем дату последней синхронизации
                lastSyncDate = data.lastUpdated
                saveLastSyncDate(data.lastUpdated)
                
                print("✅ SyncViewModel: Синхронизация завершена успешно")
            } else {
                print("ℹ️ SyncViewModel: Обновлений нет")
            }
        } catch let error as SyncError {
            // Обрабатываем ошибки синхронизации
            handleSyncError(error)
        } catch {
            print("❌ SyncViewModel: Неизвестная ошибка синхронизации: \(error)")
            syncError = "Ошибка синхронизации: \(error.localizedDescription)"
        }
        
        isSyncing = false
    }
    
    /// Обрабатывает ошибки синхронизации
    private func handleSyncError(_ error: SyncError) {
        switch error {
        case .noInternet:
            // При отсутствии интернета не показываем ошибку пользователю
            // (приложение будет работать на кешированных данных)
            print("⚠️ SyncViewModel: Нет подключения к интернету, используются кешированные данные")
            syncError = nil
            
        default:
            // Используем ErrorMessageMapper для консистентности сообщений
            syncError = ErrorMessageMapper.message(for: error)
        }
    }
    
    /// Загружает дату последней синхронизации из UserDefaults
    private func loadLastSyncDate() {
        if let timestamp = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = timestamp
        }
    }
    
    /// Сохраняет дату последней синхронизации в UserDefaults
    private func saveLastSyncDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "lastSyncDate")
    }
    
    /// Очищает ошибку синхронизации
    func clearError() {
        syncError = nil
    }
}
