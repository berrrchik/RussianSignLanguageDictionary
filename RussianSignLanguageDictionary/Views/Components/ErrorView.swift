import SwiftUI

struct ErrorView: View {
    let message: String
    let retryAction: (() -> Void)?
    let skipAction: (() -> Void)?
    
    init(message: String, retryAction: (() -> Void)? = nil, skipAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
        self.skipAction = skipAction
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Ошибка")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            HStack(spacing: 12) {
                if let retryAction = retryAction {
                    Button(action: retryAction) {
                        Label("Повторить", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Повторить попытку")
                    .accessibilityHint("Двойное нажатие для повторной загрузки")
                }
                
                if let skipAction = skipAction {
                    Button(action: skipAction) {
                        Label("Пропустить", systemImage: "arrow.right")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Пропустить видео")
                    .accessibilityHint("Двойное нажатие для перехода к следующему видео")
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ошибка: \(message)")
    }
}

// MARK: - Preview
struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ErrorView(
                message: "Не удалось загрузить данные"
            )
            .previewDisplayName("Без кнопки")
            
            ErrorView(
                message: "Ошибка сети. Проверьте подключение к интернету.",
                retryAction: { print("Retry") }
            )
            .previewDisplayName("С кнопкой повтора")
            
            ErrorView(
                message: "Видео не найдено",
                retryAction: { print("Retry") },
                skipAction: { print("Skip") }
            )
            .previewDisplayName("Ошибка видео с пропуском")
        }
    }
}

