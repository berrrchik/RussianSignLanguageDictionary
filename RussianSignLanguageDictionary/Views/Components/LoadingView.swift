import SwiftUI

struct LoadingView: View {
    let message: String
    let size: Size
    
    enum Size {
        case small
        case medium
        case large
        
        var scale: CGFloat {
            switch self {
            case .small: return LayoutConstants.LoadingView.smallScale
            case .medium: return LayoutConstants.LoadingView.mediumScale
            case .large: return LayoutConstants.LoadingView.largeScale
            }
        }
    }
    
    init(message: String = "Загрузка...", size: Size = .medium) {
        self.message = message
        self.size = size
    }
    
    var body: some View {
        VStack(spacing: LayoutConstants.LoadingView.spacing) {
            ProgressView()
                .scaleEffect(size.scale)
                .progressViewStyle(CircularProgressViewStyle())
            
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

// MARK: - Preview
struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoadingView()
                .previewDisplayName("По умолчанию")
            
            LoadingView(message: "Загрузка жестов...", size: .large)
                .previewDisplayName("Большой размер")
            
            LoadingView(message: "", size: .small)
                .previewDisplayName("Без текста")
        }
    }
}

