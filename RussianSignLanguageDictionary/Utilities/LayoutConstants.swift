import Foundation
import SwiftUI

/// Константы для Layout компонентов
enum LayoutConstants {
    
    // MARK: - Video Player
    
    enum VideoPlayer {
        /// Aspect ratio для вертикального видео (9:16)
        static let verticalAspectRatio: CGFloat = 9.0 / 16.0
        
        /// Высота видео плеера по умолчанию
        static let defaultHeight: CGFloat = 400
        
        /// Радиус скругления углов
        static let cornerRadius: CGFloat = 12
    }
    
    // MARK: - Category Card
    
    enum CategoryCard {
        /// Минимальная высота карточки категории
        static let minHeight: CGFloat = 120
        
        /// Размер иконки
        static let iconSize: CGFloat = 40
        
        /// Внутренний отступ
        static let padding: CGFloat = 16
        
        /// Радиус скругления углов
        static let cornerRadius: CGFloat = 12
        
        /// Прозрачность фона
        static let backgroundOpacity: Double = 0.1
        
        /// Минимальная ширина для адаптивной сетки
        static let gridMinWidth: CGFloat = 150
        
        /// Максимальная ширина для адаптивной сетки
        static let gridMaxWidth: CGFloat = 200
        
        /// Отступ между элементами сетки
        static let gridSpacing: CGFloat = 16
    }
    
    // MARK: - Sign Row
    
    enum SignRow {
        /// Размер миниатюры
        static let thumbnailSize: CGFloat = 60
        
        /// Радиус скругления миниатюры
        static let thumbnailCornerRadius: CGFloat = 8
        
        /// Размер иконки в миниатюре
        static let iconSize: CGFloat = 24
        
        /// Отступ между элементами
        static let spacing: CGFloat = 12
        
        /// Вертикальный padding
        static let verticalPadding: CGFloat = 8
        
        /// Горизонтальный padding для badge
        static let badgeHorizontalPadding: CGFloat = 8
        
        /// Вертикальный padding для badge
        static let badgeVerticalPadding: CGFloat = 4
    }
    
    // MARK: - Empty State
    
    enum EmptyState {
        /// Размер иконки
        static let iconSize: CGFloat = 60
        
        /// Отступ между элементами
        static let spacing: CGFloat = 20
        
        /// Горизонтальный padding для текста
        static let textHorizontalPadding: CGFloat = 32
        
        /// Горизонтальный padding для кнопки
        static let buttonHorizontalPadding: CGFloat = 24
        
        /// Вертикальный padding для кнопки
        static let buttonVerticalPadding: CGFloat = 12
        
        /// Радиус скругления кнопки
        static let buttonCornerRadius: CGFloat = 10
    }
    
    // MARK: - Loading View
    
    enum LoadingView {
        /// Отступ между элементами
        static let spacing: CGFloat = 16
        
        /// Масштаб для маленького размера
        static let smallScale: CGFloat = 0.8
        
        /// Масштаб для среднего размера
        static let mediumScale: CGFloat = 1.0
        
        /// Масштаб для большого размера
        static let largeScale: CGFloat = 1.5
    }
    
    // MARK: - Sign Detail
    
    enum SignDetail {
        /// Отступ между секциями
        static let sectionSpacing: CGFloat = 20
        
        /// Отступ между элементами
        static let elementSpacing: CGFloat = 12
        
        /// Горизонтальный padding для badge категории
        static let categoryBadgeHorizontalPadding: CGFloat = 12
        
        /// Вертикальный padding для badge категории
        static let categoryBadgeVerticalPadding: CGFloat = 6
        
        /// Радиус скругления badge
        static let badgeCornerRadius: CGFloat = 8
        
        /// Горизонтальный padding для keywords
        static let keywordHorizontalPadding: CGFloat = 10
        
        /// Вертикальный padding для keywords
        static let keywordVerticalPadding: CGFloat = 5
        
        /// Радиус скругления keywords
        static let keywordCornerRadius: CGFloat = 6
        
        /// Отступ между keywords
        static let keywordSpacing: CGFloat = 8
    }
    
    // MARK: - Opacity
    
    enum Opacity {
        /// Прозрачность для secondary элементов
        static let secondary: Double = 0.2
        
        /// Прозрачность для accent элементов
        static let accent: Double = 0.1
        
        /// Прозрачность для тени
        static let shadow: Double = 0.1
    }
    
    // MARK: - Toast/Notification
    
    enum Toast {
        /// Горизонтальный padding
        static let horizontalPadding: CGFloat = 16
        
        /// Вертикальный padding
        static let verticalPadding: CGFloat = 8
        
        /// Радиус скругления
        static let cornerRadius: CGFloat = 8
        
        /// Отступ от края экрана
        static let bottomPadding: CGFloat = 16
    }
}

