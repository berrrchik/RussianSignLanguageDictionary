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
    private let offlineStatusIcon = UIImageView()
    private let categoryContainer = UIView()
    private let favoriteIcon = UIImageView()
    private let iconView = UIView()
    private var iconViewWidthConstraint: NSLayoutConstraint?
    private var iconViewHeightConstraint: NSLayoutConstraint?
    private var offlineStatusWidthConstraint: NSLayoutConstraint?
    private var offlineStatusHeightConstraint: NSLayoutConstraint?
    private var favoriteIconWidthConstraint: NSLayoutConstraint?
    private var favoriteIconHeightConstraint: NSLayoutConstraint?
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory else {
            return
        }
        applyDynamicTypeStyles()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        signWordLabel.text = nil
        categoryLabel.text = nil
        offlineStatusIcon.image = nil
        offlineStatusIcon.tintColor = nil
        offlineStatusIcon.isHidden = true
        offlineStatusIcon.accessibilityIdentifier = nil
        favoriteIcon.isHidden = true
    }
    
    // MARK: - Configuration
    
    /// Конфигурирует ячейку данными жеста
    /// - Parameters:
    ///   - sign: Жест для отображения
    ///   - categoryName: Название категории
    ///   - isFavorite: Находится ли жест в избранном
    ///   - offlineStatus: Статус офлайн-подготовки для отображения индикатора в списке
    func configure(
        with sign: Sign,
        categoryName: String,
        isFavorite: Bool,
        offlineStatus: FavoriteOfflineStatus? = nil
    ) {
        signWordLabel.text = sign.word
        categoryLabel.text = categoryName
        favoriteIcon.isHidden = !isFavorite
        favoriteIcon.isAccessibilityElement = isFavorite
        favoriteIcon.accessibilityLabel = "В избранном"
        if let symbolName = offlineStatusSymbolName(for: offlineStatus) {
            offlineStatusIcon.image = UIImage(systemName: symbolName)
            offlineStatusIcon.tintColor = offlineStatusColor(for: offlineStatus)
            offlineStatusIcon.isHidden = false
            offlineStatusIcon.accessibilityIdentifier = "offline-status-\(symbolName)"
            offlineStatusIcon.isAccessibilityElement = true
            offlineStatusIcon.accessibilityLabel = offlineStatusAccessibilityLabel(for: offlineStatus)
        } else {
            offlineStatusIcon.image = nil
            offlineStatusIcon.tintColor = nil
            offlineStatusIcon.isHidden = true
            offlineStatusIcon.accessibilityIdentifier = nil
            offlineStatusIcon.isAccessibilityElement = false
        }
        contentView.isAccessibilityElement = true
        contentView.accessibilityLabel = accessibilityLabel(
            word: sign.word,
            category: categoryName,
            isFavorite: isFavorite,
            offlineStatus: offlineStatus
        )
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        setupIconView()
        setupSignWordLabel()
        setupCategoryBadge()
        setupOfflineStatusIcon()
        setupFavoriteIcon()
        setupConstraints()
        applyDynamicTypeStyles()
        
        accessoryType = .none
    }
    
    private func applyDynamicTypeStyles() {
        let headlineFont = UIFont.preferredFont(forTextStyle: .headline)
        signWordLabel.font = UIFont.systemFont(ofSize: headlineFont.pointSize, weight: .semibold)
        signWordLabel.adjustsFontForContentSizeCategory = true
        
        categoryLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        categoryLabel.adjustsFontForContentSizeCategory = true
        
        let iconSide = UIFontMetrics.default.scaledValue(for: 60)
        iconViewWidthConstraint?.constant = iconSide
        iconViewHeightConstraint?.constant = iconSide
        
        let accessorySide = UIFontMetrics.default.scaledValue(for: 24)
        favoriteIconWidthConstraint?.constant = accessorySide
        favoriteIconHeightConstraint?.constant = accessorySide
        
        let statusSide = UIFontMetrics.default.scaledValue(for: 16)
        offlineStatusWidthConstraint?.constant = statusSide
        offlineStatusHeightConstraint?.constant = statusSide
        
        let symbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        favoriteIcon.preferredSymbolConfiguration = symbolConfiguration
        offlineStatusIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption1)
    }
    
    private func setupIconView() {
        iconView.backgroundColor = .systemGray5
        iconView.layer.cornerRadius = 8
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isAccessibilityElement = false
        contentView.addSubview(iconView)
        
        let iconImageView = UIImageView(image: UIImage(systemName: "hand.raised.fill"))
        iconImageView.tintColor = .systemGray
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.isAccessibilityElement = false
        iconView.addSubview(iconImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func setupSignWordLabel() {
        signWordLabel.textColor = .label
        signWordLabel.numberOfLines = 1
        signWordLabel.translatesAutoresizingMaskIntoConstraints = false
        signWordLabel.isAccessibilityElement = false
        contentView.addSubview(signWordLabel)
    }

    private func setupCategoryBadge() {
        categoryContainer.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        categoryContainer.layer.cornerRadius = 8
        categoryContainer.clipsToBounds = true
        categoryContainer.translatesAutoresizingMaskIntoConstraints = false
        categoryContainer.isAccessibilityElement = false
        contentView.addSubview(categoryContainer)

        categoryLabel.textColor = .systemBlue
        categoryLabel.backgroundColor = .clear
        categoryLabel.textAlignment = .center
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryLabel.isAccessibilityElement = false
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

    private func setupOfflineStatusIcon() {
        offlineStatusIcon.translatesAutoresizingMaskIntoConstraints = false
        offlineStatusIcon.contentMode = .scaleAspectFit
        offlineStatusIcon.isHidden = true
        contentView.addSubview(offlineStatusIcon)
    }
    
    private func setupConstraints() {
        let iconWidth = iconView.widthAnchor.constraint(equalToConstant: 60)
        let iconHeight = iconView.heightAnchor.constraint(equalToConstant: 60)
        iconViewWidthConstraint = iconWidth
        iconViewHeightConstraint = iconHeight
        
        let offlineWidth = offlineStatusIcon.widthAnchor.constraint(equalToConstant: 16)
        let offlineHeight = offlineStatusIcon.heightAnchor.constraint(equalToConstant: 16)
        offlineStatusWidthConstraint = offlineWidth
        offlineStatusHeightConstraint = offlineHeight
        
        let favoriteWidth = favoriteIcon.widthAnchor.constraint(equalToConstant: 24)
        let favoriteHeight = favoriteIcon.heightAnchor.constraint(equalToConstant: 24)
        favoriteIconWidthConstraint = favoriteWidth
        favoriteIconHeightConstraint = favoriteHeight
        
        NSLayoutConstraint.activate([
            // Icon View
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconWidth,
            iconHeight,
            
            // Sign Word Label
            signWordLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            signWordLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            
            offlineStatusIcon.leadingAnchor.constraint(equalTo: signWordLabel.trailingAnchor, constant: 6),
            offlineStatusIcon.centerYAnchor.constraint(equalTo: signWordLabel.centerYAnchor),
            offlineWidth,
            offlineHeight,
            
            // Category Container
            categoryContainer.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            categoryContainer.topAnchor.constraint(equalTo: signWordLabel.bottomAnchor, constant: 4),
            categoryContainer.trailingAnchor.constraint(lessThanOrEqualTo: favoriteIcon.leadingAnchor, constant: -8),
            categoryContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            // Category Label
            categoryLabel.leadingAnchor.constraint(equalTo: categoryContainer.leadingAnchor, constant: 10),
            categoryLabel.trailingAnchor.constraint(equalTo: categoryContainer.trailingAnchor, constant: -10),
            categoryLabel.topAnchor.constraint(equalTo: categoryContainer.topAnchor, constant: 4),
            categoryLabel.bottomAnchor.constraint(equalTo: categoryContainer.bottomAnchor, constant: -4),
            
            // Favorite Icon
            favoriteIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            favoriteIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            favoriteWidth,
            favoriteHeight
        ])
    }
    
    private func offlineStatusColor(for status: FavoriteOfflineStatus?) -> UIColor {
        switch status {
        case .readyOffline:
            return .systemGreen
        case .failed:
            return .systemRed
        case .pending:
            return .systemOrange
        case nil:
            return .secondaryLabel
        }
    }

    private func offlineStatusSymbolName(for status: FavoriteOfflineStatus?) -> String? {
        switch status {
        case .readyOffline:
            return "arrow.down.to.line.compact"
        case .failed:
            return "exclamationmark.circle"
        case .pending, nil:
            return nil
        }
    }

    private func offlineStatusAccessibilityLabel(for status: FavoriteOfflineStatus?) -> String {
        switch status {
        case .readyOffline:
            return "Доступно офлайн"
        case .failed:
            return "Ошибка загрузки офлайн-копии"
        case .pending, nil:
            return ""
        }
    }

    private func accessibilityLabel(
        word: String,
        category: String,
        isFavorite: Bool,
        offlineStatus: FavoriteOfflineStatus?
    ) -> String {
        var parts = [word, category]
        if isFavorite {
            parts.append("в избранном")
        }
        let statusLabel = offlineStatusAccessibilityLabel(for: offlineStatus)
        if !statusLabel.isEmpty {
            parts.append(statusLabel)
        }
        return parts.joined(separator: ", ")
    }
}
