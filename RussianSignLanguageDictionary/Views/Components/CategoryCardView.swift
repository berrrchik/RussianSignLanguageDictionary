import SwiftUI

struct CategoryCardView: View {
    let category: Category
    
    var body: some View {
        VStack(spacing: LayoutConstants.SignDetail.elementSpacing) {
            if let iconName = category.icon {
                Image(systemName: iconName)
                    .font(.system(size: LayoutConstants.CategoryCard.iconSize))
                    .foregroundColor(.accentColor)
            } else {
                Image(systemName: "folder.fill")
                    .font(.system(size: LayoutConstants.CategoryCard.iconSize))
                    .foregroundColor(.accentColor)
            }
            
            Text(category.name)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text("\(category.signCount) жестов")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minHeight: LayoutConstants.CategoryCard.minHeight)
        .frame(maxWidth: .infinity)
        .padding(LayoutConstants.CategoryCard.padding)
        .background(Color.accentColor.opacity(LayoutConstants.CategoryCard.backgroundOpacity))
        .cornerRadius(LayoutConstants.CategoryCard.cornerRadius)
        .shadow(color: .black.opacity(LayoutConstants.Opacity.shadow), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.name), \(category.signCount) жестов")
        .accessibilityHint("Нажмите, чтобы открыть категорию")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

struct CategoryCardView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleCategory = Category(
            id: "alphabet",
            name: "Алфавит",
            order: 1,
            signCount: 33,
            icon: "textformat.abc",
            color: nil,
            createdAt: nil,
            updatedAt: nil
        )
        
        return VStack {
            CategoryCardView(category: sampleCategory)
                .padding()
            
            CategoryCardView(category: Category(
                id: "animals",
                name: "Животные",
                order: 2,
                signCount: 69,
                icon: "pawprint.fill",
                color: nil,
                createdAt: nil,
                updatedAt: nil
            ))
            .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}

