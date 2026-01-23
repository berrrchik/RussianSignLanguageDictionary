import SwiftUI

/// Компонент навигации между видео
struct VideoNavigationView: View {
    let currentIndex: Int
    let totalCount: Int
    let canGoBack: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onPrevious) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Предыдущее")
                }
            }
            .disabled(!canGoBack)
            
            Spacer()
            
            Text("\(currentIndex + 1) из \(totalCount)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: onNext) {
                HStack {
                    Text("Следующее")
                    Image(systemName: "chevron.right")
                }
            }
            .disabled(!canGoNext)
        }
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct VideoNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            VideoNavigationView(
                currentIndex: 0,
                totalCount: 3,
                canGoBack: false,
                canGoNext: true,
                onPrevious: { print("Previous") },
                onNext: { print("Next") }
            )
            .previewDisplayName("Первое видео")
            
            VideoNavigationView(
                currentIndex: 1,
                totalCount: 3,
                canGoBack: true,
                canGoNext: true,
                onPrevious: { print("Previous") },
                onNext: { print("Next") }
            )
            .previewDisplayName("Среднее видео")
            
            VideoNavigationView(
                currentIndex: 2,
                totalCount: 3,
                canGoBack: true,
                canGoNext: false,
                onPrevious: { print("Previous") },
                onNext: { print("Next") }
            )
            .previewDisplayName("Последнее видео")
        }
        .padding()
    }
}
#endif
