import SwiftUI

struct SignRowView: View {
    let sign: Sign
    let showFavoriteIndicator: Bool
    let isFavorite: Bool
    
    init(sign: Sign, showFavoriteIndicator: Bool = false, isFavorite: Bool = false) {
        self.sign = sign
        self.showFavoriteIndicator = showFavoriteIndicator
        self.isFavorite = isFavorite
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: LayoutConstants.SignRow.spacing) {
            placeholderImage
            
            VStack(alignment: .leading, spacing: 12) {
                Text(sign.word)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(CategoryService.name(for: sign.category))
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, LayoutConstants.SignRow.badgeHorizontalPadding)
                    .padding(.vertical, LayoutConstants.SignRow.badgeVerticalPadding)
                    .background(Color.accentColor.opacity(LayoutConstants.Opacity.accent))
                    .cornerRadius(LayoutConstants.SignDetail.badgeCornerRadius)
            }
            
            Spacer()
            
            if showFavoriteIndicator && isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                    .accessibilityLabel("В избранном")
            }
        }
        .padding(.vertical, LayoutConstants.SignRow.verticalPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sign.word), \(CategoryService.name(for: sign.category))")
        .accessibilityHint("Нажмите для просмотра деталей")
    }
    
    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: LayoutConstants.SignRow.thumbnailCornerRadius)
            .fill(Color.secondary.opacity(LayoutConstants.Opacity.secondary))
            .frame(width: LayoutConstants.SignRow.thumbnailSize, height: LayoutConstants.SignRow.thumbnailSize)
            .overlay(
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: LayoutConstants.SignRow.iconSize))
                    .foregroundColor(.secondary)
            )
    }
}

// MARK: - Preview
struct SignRowView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSign = Sign(
            id: "sign_001",
            word: "Привет",
            description: "Жест приветствия",
            category: "общение",
            videos: nil,
            synonyms: nil,
            embeddings: nil,
            videoId: "video_001",
            supabaseStoragePath: "signs/hello.mp4",
            supabaseUrl: "https://example.com/video.mp4",
            keywords: ["привет", "здравствуй"],
            metadata: SignMetadata(
                duration: 3.5,
                fileSize: 512000,
                resolution: "1080x1920",
                format: "mp4",
                fps: 30
            )
        )
        
        return Group {
            List {
                SignRowView(sign: sampleSign)
                SignRowView(sign: sampleSign, showFavoriteIndicator: true, isFavorite: true)
                SignRowView(sign: sampleSign, showFavoriteIndicator: true, isFavorite: false)
            }
            .previewDisplayName("Варианты отображения")
        }
    }
}

