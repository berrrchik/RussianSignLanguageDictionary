import SwiftUI

/// Строка-ссылка для списка настроек: иконка + заголовок + опциональная стрелка "внешняя ссылка".
struct SettingsLinkRow: View {
    let icon: String
    let title: String
    var showsExternalIndicator: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                if showsExternalIndicator {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
}
