import SwiftUI
import UIKit

struct AlphabeticScrollbarTableView: UIViewRepresentable {
    let sections: [SearchViewModel.SignSection]
    let favoritesRepository: FavoritesRepositoryProtocol?
    let categoryNamesById: [String: String]
    let favoriteOfflineStatusProvider: ((String) -> FavoriteOfflineStatus?)?
    let onSignSelected: (Sign) -> Void
    
    func makeUIView(context: Context) -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.register(SignRowTableViewCell.self, forCellReuseIdentifier: "SignCell")
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 24)
        tableView.sectionIndexColor = .systemBlue
        tableView.sectionIndexBackgroundColor = .clear
        tableView.sectionIndexTrackingBackgroundColor = .clear
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.sectionHeaderTopPadding = 0
        context.coordinator.tableView = tableView
        
        return tableView
    }
    
    func updateUIView(_ uiView: UITableView, context: Context) {
        context.coordinator.sections = sections
        context.coordinator.favoritesRepository = favoritesRepository
        context.coordinator.categoryNamesById = categoryNamesById
        context.coordinator.favoriteOfflineStatusProvider = favoriteOfflineStatusProvider
        context.coordinator.tableView = uiView
        if uiView.window != nil {
            uiView.reloadData()
        } else {
            DispatchQueue.main.async {
                guard uiView.window != nil else { return }
                uiView.reloadData()
            }
        }
    }
    
    static func dismantleUIView(_ uiView: UITableView, coordinator: Coordinator) {
        uiView.delegate = nil
        uiView.dataSource = nil
        coordinator.cleanup()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            sections: sections,
            favoritesRepository: favoritesRepository,
            categoryNamesById: categoryNamesById,
            favoriteOfflineStatusProvider: favoriteOfflineStatusProvider,
            onSignSelected: onSignSelected
        )
    }
    
    class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        var sections: [SearchViewModel.SignSection]
        var favoritesRepository: FavoritesRepositoryProtocol?
        var categoryNamesById: [String: String]
        var favoriteOfflineStatusProvider: ((String) -> FavoriteOfflineStatus?)?
        let onSignSelected: (Sign) -> Void
        weak var tableView: UITableView?
        
        init(
            sections: [SearchViewModel.SignSection],
            favoritesRepository: FavoritesRepositoryProtocol?,
            categoryNamesById: [String: String],
            favoriteOfflineStatusProvider: ((String) -> FavoriteOfflineStatus?)?,
            onSignSelected: @escaping (Sign) -> Void
        ) {
            self.sections = sections
            self.favoritesRepository = favoritesRepository
            self.categoryNamesById = categoryNamesById
            self.favoriteOfflineStatusProvider = favoriteOfflineStatusProvider
            self.onSignSelected = onSignSelected
            super.init()
        }
        
        func cleanup() {
            sections.removeAll()
            favoritesRepository = nil
            favoriteOfflineStatusProvider = nil
        }
        
        // MARK: - UITableViewDataSource
        
        func numberOfSections(in tableView: UITableView) -> Int {
            return sections.count
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            guard section < sections.count else { return 0 }
            return sections[section].signs.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            guard indexPath.section < sections.count,
                  indexPath.row < sections[indexPath.section].signs.count else {
                return UITableViewCell()
            }
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SignCell", for: indexPath) as? SignRowTableViewCell else {
                return UITableViewCell()
            }
            let sign = sections[indexPath.section].signs[indexPath.row]
            let isFavorite = favoritesRepository?.isFavorite(signId: sign.id) ?? false
            let categoryName = CategoryDisplayDataHelper.name(
                for: sign.categoryId,
                in: categoryNamesById
            )
            let offlineStatus = favoriteOfflineStatusProvider?(sign.id)
            
            cell.configure(
                with: sign,
                categoryName: categoryName,
                isFavorite: isFavorite,
                offlineStatus: offlineStatus
            )
            
            return cell
        }
        
        func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            guard section < sections.count else { return nil }
            let letter = sections[section].letter
            return letter.isEmpty ? nil : letter
        }
        
        func sectionIndexTitles(for tableView: UITableView) -> [String]? {
            let hasSearchMode = sections.contains { $0.letter.isEmpty }
            if hasSearchMode {
                return nil
            }
            return sections.map { $0.letter }
        }
        
        func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
            return sections.firstIndex(where: { $0.letter == title }) ?? index
        }
        
        // MARK: - UITableViewDelegate
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: false)
            
            guard indexPath.section < sections.count,
                  indexPath.row < sections[indexPath.section].signs.count else {
                return
            }
            
            let sign = sections[indexPath.section].signs[indexPath.row]
            onSignSelected(sign)
        }
        
        func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
            return 28
        }
    }
}
