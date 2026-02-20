import SwiftUI

struct NavigationBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Назад")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .accessibilityLabel("Назад")
                }
            }
    }
}

extension View {
    func navigationBackButton() -> some View {
        modifier(NavigationBackButtonModifier())
    }
}
