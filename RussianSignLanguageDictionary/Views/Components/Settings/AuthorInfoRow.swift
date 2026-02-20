import SwiftUI

/// Компонент для отображения информации об авторе приложения
struct AuthorInfoRow: View {
    // MARK: - Properties
    
    let author: AuthorInfo
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Разработчик")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(author.name)
                .font(.body)
            
            if let email = author.email {
                Button(action: {
                    if let emailURL = URL(string: "mailto:\(email)") {
                        UIApplication.shared.open(emailURL)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope")
                            .font(.caption)
                        Text(email)
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            if let github = author.github, let githubURL = URL(string: github) {
                Button(action: {
                    UIApplication.shared.open(githubURL)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption)
                        Text("GitHub")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
