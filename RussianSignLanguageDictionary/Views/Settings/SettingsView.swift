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
                        Button(action: {
                            if let emailURL = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(emailURL)
                            }
                        }) {
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text(email)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                    
                    // GitHub
                    if let github = viewModel.appInfo.author.github, let githubURL = URL(string: github) {
                        Button(action: {
                            UIApplication.shared.open(githubURL)
                        }) {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text("GitHub")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                // Секция "Партнёры"
                Section("Партнёры") {
                    VOGInfoRow(vogInfo: viewModel.vogInfo)
                    
                    // Официальный сайт
                    Button(action: {
                        UIApplication.shared.open(viewModel.vogInfo.websiteURL)
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
                        UIApplication.shared.open(viewModel.vogInfo.contactsURL)
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
                        let phoneNumber = viewModel.vogInfo.phone
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
                            Text(viewModel.vogInfo.phone)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    
                    // Социальные сети
                    if !viewModel.vogInfo.socialNetworks.isEmpty {
                        ForEach(viewModel.vogInfo.socialNetworks, id: \.name) { network in
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
                
                // Секция "Обратная связь"
//                Section("Обратная связь") {
//                    Button(action: {
//                        viewModel.openAppStoreReview()
//                    }) {
//                        HStack {
//                            Image(systemName: "star.fill")
//                                .foregroundColor(.blue)
//                                .frame(width: 24)
//                            Text("Оставить отзыв")
//                                .foregroundColor(.primary)
//                            Spacer()
//                            Image(systemName: "arrow.up.right.square")
//                                .foregroundColor(.secondary)
//                                .font(.caption)
//                        }
//                    }
//                    
//                    Button(action: {
//                        viewModel.reportBug()
//                    }) {
//                        HStack {
//                            Image(systemName: "exclamationmark.triangle.fill")
//                                .foregroundColor(.blue)
//                                .frame(width: 24)
//                            Text("Сообщить об ошибке")
//                                .foregroundColor(.primary)
//                            Spacer()
//                            Image(systemName: "arrow.up.right.square")
//                                .foregroundColor(.secondary)
//                                .font(.caption)
//                        }
//                    }
//                    
//                    Button(action: {
//                        viewModel.shareApp()
//                    }) {
//                        HStack {
//                            Image(systemName: "square.and.arrow.up")
//                                .foregroundColor(.blue)
//                                .frame(width: 24)
//                            Text("Поделиться приложением")
//                                .foregroundColor(.primary)
//                            Spacer()
//                        }
//                    }
//                }
                
                // Секция "Интерфейс"
//                Section("Интерфейс") {
//                    Picker("Размер шрифта", selection: $viewModel.fontSize) {
//                        ForEach(SettingsViewModel.FontSize.allCases, id: \.self) { size in
//                            Text(size.rawValue).tag(size)
//                        }
//                    }
//                    
//                    Toggle("Тёмная тема", isOn: $viewModel.darkMode)
//                }
                
                // Секция "Настройки"
                Section("Настройки") {
//                    Toggle("Автоповтор видео", isOn: $viewModel.autoRepeatVideo)
//                    Toggle("Автозагрузка видео", isOn: $viewModel.autoDownloadVideo)
                    
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
