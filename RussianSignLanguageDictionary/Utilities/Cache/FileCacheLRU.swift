import Foundation

/// Утилита для LRU-очистки файлового кеша
///
/// Единый алгоритм вытеснения старых файлов по размеру.
/// Используется в `VideoRepository` (краткосрочный кеш, 150MB)
/// и `VideoCacheDirectoryManager` (долгосрочный кеш, 500MB).
enum FileCacheLRU {
    
    /// Проверяет размер директории и удаляет самые старые файлы при превышении лимита
    ///
    /// Алгоритм:
    /// 1. Считаем суммарный размер файлов в директории
    /// 2. Если размер ≤ `maxSize` — ничего не делаем
    /// 3. Если превышает — сортируем файлы по дате изменения (старые первые)
    /// 4. Удаляем по одному, пока размер не станет ≤ `targetSize` (процент от `maxSize`)
    ///
    /// - Parameters:
    ///   - directory: Директория с файлами кеша
    ///   - maxSize: Максимальный размер в байтах
    ///   - targetPercent: Целевой процент от лимита после очистки (по умолчанию 80%)
    /// - Returns: Количество удалённых файлов
    @discardableResult
    @Sendable static func enforceSizeLimit(
        at directory: URL,
        maxSize: Int,
        targetPercent: Int = 80
    ) -> Int {
        let fileManager = FileManager.default
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return 0 }
        
        // Собираем информацию о файлах
        var totalSize = 0
        var fileInfos: [(url: URL, size: Int, date: Date)] = []
        
        for file in files {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = values?.fileSize ?? 0
            let date = values?.contentModificationDate ?? .distantPast
            totalSize += size
            fileInfos.append((url: file, size: size, date: date))
        }
        
        // Если в пределах лимита — ничего не делаем
        guard totalSize > maxSize else { return 0 }
        
        // Сортируем по дате: самые старые первые (они будут удалены)
        fileInfos.sort { $0.date < $1.date }
        
        let targetSize = maxSize * targetPercent / 100
        var freedSize = 0
        var removedCount = 0
        
        for fileInfo in fileInfos {
            if totalSize - freedSize <= targetSize {
                break
            }
            try? fileManager.removeItem(at: fileInfo.url)
            freedSize += fileInfo.size
            removedCount += 1
        }
        
        return removedCount
    }
}
