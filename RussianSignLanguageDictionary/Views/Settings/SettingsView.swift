import SwiftUI

/// Экран настроек приложения
struct SettingsView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showClearCacheAlert = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                // Секция "О приложении"
                Section("О приложении") {
                    AppInfoRow(appInfo: viewModel.appInfo)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Описание")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(viewModel.appInfo.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    
                    // Информация об авторе
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Разработчик")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(viewModel.appInfo.author.name)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                    
                    // Email
                    if let email = viewModel.appInfo.author.email {
                        SettingsLinkRow(icon: "envelope", title: email, showsExternalIndicator: false) {
                            if let emailURL = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(emailURL)
                            }
                        }
                    }

                    // GitHub
                    if let github = viewModel.appInfo.author.github, let githubURL = URL(string: github) {
                        SettingsLinkRow(icon: "link", title: "GitHub") {
                            UIApplication.shared.open(githubURL)
                        }
                    }
                }
                
                // Секция "Партнёры"
                Section("Партнёры") {
                    VOGInfoRow(vogInfo: viewModel.vogInfo)
                    
                    // Официальный сайт
                    SettingsLinkRow(icon: "globe", title: "Официальный сайт") {
                        UIApplication.shared.open(viewModel.vogInfo.websiteURL)
                    }

                    // Контакты
                    SettingsLinkRow(icon: "person.2", title: "Контакты") {
                        UIApplication.shared.open(viewModel.vogInfo.contactsURL)
                    }

                    // Телефон
                    SettingsLinkRow(icon: "phone", title: viewModel.vogInfo.phone, showsExternalIndicator: false) {
                        let phoneNumber = viewModel.vogInfo.phone
                            .replacingOccurrences(of: " ", with: "")
                            .replacingOccurrences(of: "(", with: "")
                            .replacingOccurrences(of: ")", with: "")
                            .replacingOccurrences(of: "-", with: "")
                        if let phoneURL = URL(string: "tel://\(phoneNumber)") {
                            UIApplication.shared.open(phoneURL)
                        }
                    }

                    // Социальные сети
                    ForEach(viewModel.vogInfo.socialNetworks, id: \.name) { network in
                        SettingsLinkRow(icon: network.iconName, title: network.name) {
                            UIApplication.shared.open(network.url)
                        }
                    }
                }
                
                // Секция "Настройки"
                Section("Настройки") {
                    Button("Очистить кэш") {
                        showClearCacheAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Настройки")
            .alert("Очистить кэш?", isPresented: $showClearCacheAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Очистить", role: .destructive) {
                    viewModel.clearCache()
                }
            } message: {
                Text("Все закэшированные видео будут удалены. Это действие нельзя отменить.")
            }
            .alert("Кэш очищен", isPresented: Binding(
                get: { viewModel.cacheClearedMessage != nil },
                set: { if !$0 { viewModel.cacheClearedMessage = nil } }
            )) {
                Button("OK") {
                    viewModel.cacheClearedMessage = nil
                }
            } message: {
                if let message = viewModel.cacheClearedMessage {
                    Text(message)
                }
            }
            .onAppear {
                AnalyticsService.logScreenView(screenName: "settings", screenClass: "SettingsView")
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environment(\.dependencies, .preview)
    }
}
#endif
