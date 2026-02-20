import SwiftUI

/// Компонент для отображения информации о приложении
struct AppInfoRow: View {
    // MARK: - Properties
    
    let appInfo: AppInfo
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appInfo.name)
                .font(.headline)
            Text("Версия \(appInfo.version) (\(appInfo.buildNumber))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
