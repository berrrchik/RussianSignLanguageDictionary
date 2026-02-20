import SwiftUI

/// Компонент для отображения ссылок на ВОГ
struct VOGLinksRow: View {
    // MARK: - Properties
    
    let vogInfo: VOGInfo
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Официальный сайт
            Button(action: {
                UIApplication.shared.open(vogInfo.websiteURL)
            }) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Официальный сайт")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            // Контакты
            Button(action: {
                UIApplication.shared.open(vogInfo.contactsURL)
            }) {
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Контакты")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            // Телефон
            Button(action: {
                let phoneNumber = vogInfo.phone
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                    .replacingOccurrences(of: "-", with: "")
                if let phoneURL = URL(string: "tel://\(phoneNumber)") {
                    UIApplication.shared.open(phoneURL)
                }
            }) {
                HStack {
                    Image(systemName: "phone")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text(vogInfo.phone)
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            
            // Социальные сети
            if !vogInfo.socialNetworks.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                ForEach(vogInfo.socialNetworks, id: \.name) { network in
                    Button(action: {
                        UIApplication.shared.open(network.url)
                    }) {
                        HStack {
                            Image(systemName: network.iconName)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(network.name)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
