import UIKit

/// Ячейка для отображения жеста в UITableView
///
/// Содержит:
/// - Иконку жеста
/// - Название жеста
/// - Категорию (бейдж)
/// - Индикатор избранного (сердечко)
final class SignRowTableViewCell: UITableViewCell {
    // MARK: - UI Components
    
    private let signWordLabel = UILabel()
    private let categoryLabel = UILabel()
    private let categoryContainer = UIView()
    private let favoriteIcon = UIImageView()
    private let iconView = UIView()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func prepareForReuse() {
        super.prepareForReuse()
        signWordLabel.text = nil
        categoryLabel.text = nil
        favoriteIcon.isHidden = true
    }
    
    // MARK: - Configuration
    
    /// Конфигурирует ячейку данными жеста
    /// - Parameters:
    ///   - sign: Жест для отображения
    ///   - categoryName: Название категории
    ///   - isFavorite: Находится ли жест в избранном
    func configure(with sign: Sign, categoryName: String, isFavorite: Bool) {
        signWordLabel.text = sign.word
        categoryLabel.text = categoryName
        favoriteIcon.isHidden = !isFavorite
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        setupIconView()
        setupSignWordLabel()
        setupCategoryBadge()
        setupFavoriteIcon()
        setupConstraints()
        
        accessoryType = .none
    }
    
    private func setupIconView() {
        iconView.backgroundColor = .systemGray5
        iconView.layer.cornerRadius = 8
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)
        
        let iconImageView = UIImageView(image: UIImage(systemName: "hand.raised.fill"))
        iconImageView.tintColor = .systemGray
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func setupSignWordLabel() {
        signWordLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        signWordLabel.textColor = .label
        signWordLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(signWordLabel)
    }
    
    private func setupCategoryBadge() {
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
    }
    
    private func setupFavoriteIcon() {
        favoriteIcon.image = UIImage(systemName: "heart.fill")
        favoriteIcon.tintColor = .systemRed
        favoriteIcon.contentMode = .scaleAspectFit
        favoriteIcon.translatesAutoresizingMaskIntoConstraints = false
        favoriteIcon.isHidden = true
        contentView.addSubview(favoriteIcon)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Icon View
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 60),
            iconView.heightAnchor.constraint(equalToConstant: 60),
            
            // Sign Word Label
            signWordLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            signWordLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            signWordLabel.trailingAnchor.constraint(lessThanOrEqualTo: favoriteIcon.leadingAnchor, constant: -8),
            
            // Category Container
            categoryContainer.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            categoryContainer.topAnchor.constraint(equalTo: signWordLabel.bottomAnchor, constant: 4),
            categoryContainer.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16),
            categoryContainer.trailingAnchor.constraint(lessThanOrEqualTo: favoriteIcon.leadingAnchor, constant: -8),
            categoryContainer.heightAnchor.constraint(equalToConstant: 24),
            
            // Category Label
            categoryLabel.leadingAnchor.constraint(equalTo: categoryContainer.leadingAnchor, constant: 10),
            categoryLabel.trailingAnchor.constraint(equalTo: categoryContainer.trailingAnchor, constant: -10),
            categoryLabel.topAnchor.constraint(equalTo: categoryContainer.topAnchor, constant: 4),
            categoryLabel.bottomAnchor.constraint(equalTo: categoryContainer.bottomAnchor, constant: -4),
            
            // Favorite Icon
            favoriteIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            favoriteIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            favoriteIcon.widthAnchor.constraint(equalToConstant: 24),
            favoriteIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
}
