import SwiftUI

struct StartupSplashScreen: View {
    @State private var breatheActive = false
    @State private var dot1Active = false
    @State private var dot2Active = false
    @State private var dot3Active = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                animatedIconArea
                    .padding(.bottom, 20)

                Text("Словарь жестового языка")
                    .font(.headline)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("Загрузка…")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                HStack(spacing: 8) {
                    SplashDot(alpha: dot1Active ? 1.0 : 0.25)
                    SplashDot(alpha: dot2Active ? 1.0 : 0.25)
                    SplashDot(alpha: dot3Active ? 1.0 : 0.25)
                }
                .padding(.top, 22)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                breatheActive = true
            }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                dot1Active = true
            }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(0.16)) {
                dot2Active = true
            }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(0.32)) {
                dot3Active = true
            }
        }
    }

    private var animatedIconArea: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 108, height: 108)
                .scaleEffect(breatheActive ? 1.03 : 0.98)
                .opacity(breatheActive ? 0.18 : 0.10)

            Image(systemName: "book")
                .font(.system(size: 74))
                .foregroundStyle(Color.accentColor)
                .scaleEffect(breatheActive ? 1.03 : 0.98)
                .accessibilityHidden(true)
        }
        .frame(width: 132, height: 132)
    }

    private struct SplashDot: View {
        let alpha: Double
        var body: some View {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
                .opacity(alpha)
        }
    }
}