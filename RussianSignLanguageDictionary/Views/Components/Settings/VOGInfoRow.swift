import SwiftUI

/// Компонент для отображения информации о ВОГ
struct VOGInfoRow: View {
    // MARK: - Properties
    
    let vogInfo: VOGInfo
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(vogInfo.name)
                .font(.headline)
            
            Text(vogInfo.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}
