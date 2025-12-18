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
    private let networkMonitor: NetworkMonitorProtocol
    
    // MARK: - Initialization
    
    init(
        syncRepository: SyncRepositoryProtocol,
        cacheService: CacheService,
        networkMonitor: NetworkMonitorProtocol = NetworkMonitor()
    ) {
        self.syncRepository = syncRepository
        self.cacheService = cacheService
        self.networkMonitor = networkMonitor
        
        // Загружаем дату последней синхронизации из кеша
        loadLastSyncDate()
    }
    
    // MARK: - Methods
    
    /// Выполняет синхронизацию данных
    /// 
    /// **Важно**: Сначала проверяет наличие интернета.
    /// Если интернета нет - НЕ показывает overlay синхронизации,
    /// приложение работает на кешированных данных.
    func sync() async {
        // СНАЧАЛА проверяем интернет, чтобы не показывать overlay зря
        let isConnected = await networkMonitor.checkConnection()
        
        if !isConnected {
            print("⚠️ SyncViewModel: Нет подключения к интернету, синхронизация пропущена")
            // НЕ показываем overlay и НЕ показываем ошибку
            // Приложение будет работать на кешированных данных
            return
        }
        
        // Есть интернет - показываем overlay и синхронизируем
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
            
        case .serverUnavailable:
            // Сервер недоступен - не показываем ошибку если есть кеш
            // (приложение будет работать на кешированных данных)
            print("⚠️ SyncViewModel: Сервер недоступен, используются кешированные данные")
            syncError = nil
            
        case .networkError:
            // Ошибка сети - не показываем ошибку если есть кеш
            print("⚠️ SyncViewModel: Ошибка сети, используются кешированные данные")
            syncError = nil
            
        default:
            // Другие ошибки показываем пользователю
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
