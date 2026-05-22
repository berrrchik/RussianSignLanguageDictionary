import SwiftUI

struct SignRowView: View {
    @ScaledMetric(relativeTo: .body) private var thumbnailSize = LayoutConstants.SignRow.thumbnailSize
    @ScaledMetric(relativeTo: .body) private var iconSize = LayoutConstants.SignRow.iconSize
    let sign: Sign
    let categoryName: String
    let showFavoriteIndicator: Bool
    let isFavorite: Bool
    
    init(
        sign: Sign,
        categoryName: String,
        showFavoriteIndicator: Bool = false,
        isFavorite: Bool = false
    ) {
        self.sign = sign
        self.categoryName = categoryName
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
                
                Text(categoryName)
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
                    .font(.body)
                    .foregroundColor(.red)
                    .accessibilityLabel("В избранном")
            }
        }
        .padding(.vertical, LayoutConstants.SignRow.verticalPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sign.word), \(categoryName)")
        .accessibilityHint("Нажмите для просмотра деталей")
    }
    
    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: LayoutConstants.SignRow.thumbnailCornerRadius)
            .fill(Color.secondary.opacity(LayoutConstants.Opacity.secondary))
            .frame(width: thumbnailSize, height: thumbnailSize)
            .overlay(
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.secondary)
            )
    }
}

// MARK: - Preview
#if DEBUG
struct SignRowView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSign = Sign(
            id: "sign_001",
            word: "Привет",
            description: "Жест приветствия",
            categoryId: "общение",
            videos: [
                SignVideo(
                    id: 1,
                    url: "https://example.com/video.mp4",
                    contextDescription: "Основное видео",
                    order: 0,
                    createdAt: nil,
                    updatedAt: nil
                )
            ],
            synonyms: nil
        )

        return Group {
            List {
                SignRowView(sign: sampleSign, categoryName: "Общение")
                SignRowView(sign: sampleSign, categoryName: "Общение", showFavoriteIndicator: true, isFavorite: true)
                SignRowView(sign: sampleSign, categoryName: "Общение", showFavoriteIndicator: true, isFavorite: false)
            }
            .previewDisplayName("Варианты отображения")
        }
    }
}
#endif
