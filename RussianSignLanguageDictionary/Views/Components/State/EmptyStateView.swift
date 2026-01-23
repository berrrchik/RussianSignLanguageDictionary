import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let hint: String?
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        hint: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.hint = hint
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: LayoutConstants.EmptyState.spacing) {
            Image(systemName: icon)
                .font(.system(size: LayoutConstants.EmptyState.iconSize))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if let hint = hint {
                    Text(hint)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, LayoutConstants.EmptyState.textHorizontalPadding)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .padding(.horizontal, LayoutConstants.EmptyState.buttonHorizontalPadding)
                        .padding(.vertical, LayoutConstants.EmptyState.buttonVerticalPadding)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(LayoutConstants.EmptyState.buttonCornerRadius)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityHint(hint ?? "")
    }
}

// MARK: - Preview
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "Ничего не найдено",
                message: "Попробуйте изменить запрос"
            )
            .previewDisplayName("Поиск пустой")
            
            EmptyStateView(
                icon: "heart",
                title: "У вас пока нет избранных жестов",
                message: "Добавьте жесты в избранное для быстрого доступа",
                hint: "Нажмите ❤️ на любом жесте"
            )
            .previewDisplayName("Избранное пустое")
            
            EmptyStateView(
                icon: "exclamationmark.triangle",
                title: "Что-то пошло не так",
                message: "Не удалось загрузить данные",
                actionTitle: "Повторить",
                action: { print("Retry") }
            )
            .previewDisplayName("С кнопкой действия")
        }
    }
}

