import SwiftUI

/// Шторка-объяснение перед системным диалогом ATT
struct TrackingPrimerView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
                .padding(.top, 32)
                .accessibilityHidden(true)

            VStack(spacing: 24) {
                Text("Аналитика")
                    .font(.title2.bold())

                Text("Мы используем аналитику для улучшения приложения. Ваши данные остаются анонимными.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
            }
            .accessibilityElement(children: .combine)

//            Spacer()

            Button(action: onContinue) {
                Text("Продолжить")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Продолжить")
            .accessibilityHint("Открывает системный запрос разрешения на отслеживание")
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
    }
}

#if DEBUG
#Preview {
    TrackingPrimerView(onContinue: {})
}
#endif
