import Foundation

/// Метаданные видео файла жеста
struct SignMetadata: Codable, Hashable {
    /// Длительность видео в секундах
    let duration: Double?
    
    /// Размер файла в байтах
    let fileSize: Int?
    
    /// Разрешение видео (например, "1080x1920")
    let resolution: String?
    
    /// Формат видео (например, "mp4")
    let format: String?
    
    /// Количество кадров в секунду
    let fps: Int?
}

