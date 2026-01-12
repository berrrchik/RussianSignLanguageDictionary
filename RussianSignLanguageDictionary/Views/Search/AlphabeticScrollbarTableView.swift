import SwiftUI
import UIKit

struct AlphabeticScrollbarTableView: UIViewRepresentable {
    let sections: [SearchViewModel.SignSection]
    let signRepository: SignRepositoryProtocol
    let videoRepository: VideoRepositoryProtocol
    let favoritesRepository: FavoritesRepositoryProtocol?
    let getCategoryName: (String) -> String
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
        return tableView
    }
    
    func updateUIView(_ uiView: UITableView, context: Context) {
        context.coordinator.sections = sections
        uiView.reloadData()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        var parent: AlphabeticScrollbarTableView
        var sections: [SearchViewModel.SignSection] = []
        
        init(_ parent: AlphabeticScrollbarTableView) {
            self.parent = parent
        }
        
        // MARK: - UITableViewDataSource
        
        func numberOfSections(in tableView: UITableView) -> Int {
            return sections.count
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return sections[section].signs.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SignCell", for: indexPath) as! SignRowTableViewCell
            let sign = sections[indexPath.section].signs[indexPath.row]
            let isFavorite = parent.favoritesRepository?.isFavorite(signId: sign.id) ?? false
            let categoryName = parent.getCategoryName(sign.categoryId)
            
            cell.configure(with: sign, categoryName: categoryName, isFavorite: isFavorite)
            
            return cell
        }
        
        func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            return sections[section].letter
        }
        
        func sectionIndexTitles(for tableView: UITableView) -> [String]? {
            // Возвращаем массив букв для системного scrollbar
            return sections.map { $0.letter }
        }
        
        func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
            // Находим индекс секции по букве
            return sections.firstIndex(where: { $0.letter == title }) ?? index
        }
        
        // MARK: - UITableViewDelegate
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            let sign = sections[indexPath.section].signs[indexPath.row]
            parent.onSignSelected(sign)
        }
        
        func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
            return 28
        }
        
        func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            return 80
        }
    }
}

// MARK: - Custom Cell

class SignRowTableViewCell: UITableViewCell {
    private let signWordLabel = UILabel()
    private let categoryLabel = UILabel()
    private let categoryContainer = UIView()
    private let favoriteIcon = UIImageView()
    private let iconView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Настройка иконки
        iconView.backgroundColor = .systemGray5
        iconView.layer.cornerRadius = 8
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)
        
        let iconImageView = UIImageView(image: UIImage(systemName: "hand.raised.fill"))
        iconImageView.tintColor = .systemGray
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconImageView)
        
        // Настройка текста слова
        signWordLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        signWordLabel.textColor = .label
        signWordLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(signWordLabel)
        
        // Настройка категории - оборачиваем в контейнер для padding
        categoryContainer.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        categoryContainer.layer.cornerRadius = 8
        categoryContainer.clipsToBounds = true
        categoryContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(categoryContainer)
        
        categoryLabel.font = .systemFont(ofSize: 12, weight: .medium)
        categoryLabel.textColor = .systemBlue
        categoryLabel.backgroundColor = .clear
        categoryLabel.textAlignment = .center
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryContainer.addSubview(categoryLabel)
        
        // Настройка иконки избранного
        favoriteIcon.image = UIImage(systemName: "heart.fill")
        favoriteIcon.tintColor = .systemRed
        favoriteIcon.contentMode = .scaleAspectFit
        favoriteIcon.translatesAutoresizingMaskIntoConstraints = false
        favoriteIcon.isHidden = true
        contentView.addSubview(favoriteIcon)
        
        // Убираем accessory (chevron)
        accessoryType = .none
        
        // Constraints
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 60),
            iconView.heightAnchor.constraint(equalToConstant: 60),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            signWordLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            signWordLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            signWordLabel.trailingAnchor.constraint(lessThanOrEqualTo: favoriteIcon.leadingAnchor, constant: -8),
            
            categoryContainer.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            categoryContainer.topAnchor.constraint(equalTo: signWordLabel.bottomAnchor, constant: 8),
            categoryContainer.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16),
            categoryContainer.trailingAnchor.constraint(lessThanOrEqualTo: favoriteIcon.leadingAnchor, constant: -8),
            categoryContainer.heightAnchor.constraint(equalToConstant: 24),
            
            categoryLabel.leadingAnchor.constraint(equalTo: categoryContainer.leadingAnchor, constant: 10),
            categoryLabel.trailingAnchor.constraint(equalTo: categoryContainer.trailingAnchor, constant: -10),
            categoryLabel.topAnchor.constraint(equalTo: categoryContainer.topAnchor, constant: 4),
            categoryLabel.bottomAnchor.constraint(equalTo: categoryContainer.bottomAnchor, constant: -4),
            
            favoriteIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            favoriteIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            favoriteIcon.widthAnchor.constraint(equalToConstant: 24),
            favoriteIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func configure(with sign: Sign, categoryName: String, isFavorite: Bool) {
        signWordLabel.text = sign.word
        categoryLabel.text = categoryName
        favoriteIcon.isHidden = !isFavorite
    }
}
