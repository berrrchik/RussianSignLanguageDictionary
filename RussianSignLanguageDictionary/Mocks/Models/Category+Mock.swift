import Foundation

#if DEBUG
extension Category {
    /// Создает тестовый объект Category для превью и тестов
    /// - Parameters:
    ///   - id: Уникальный идентификатор категории
    ///   - name: Название категории
    ///   - order: Порядковый номер
    ///   - signCount: Количество жестов
    ///   - icon: SF Symbol иконка
    ///   - color: Цвет в hex формате
    /// - Returns: Тестовый объект Category
    static func mock(
        id: String = "alphabet",
        name: String = "Алфавит",
        order: Int = 1,
        signCount: Int = 33,
        icon: String = "textformat.abc",
        color: String? = nil
    ) -> Category {
        Category(
            id: id,
            name: name,
            order: order,
            signCount: signCount,
            icon: icon,
            color: color,
            createdAt: nil,
            updatedAt: nil
        )
    }
    
    /// Создает массив тестовых категорий
    static func mockArray() -> [Category] {
        [
            .mock(id: "alphabet", name: "Алфавит", order: 1, signCount: 33, icon: "textformat.abc"),
            .mock(id: "emotions", name: "Эмоции", order: 2, signCount: 45, icon: "face.smiling"),
            .mock(id: "animals", name: "Животные", order: 3, signCount: 69, icon: "pawprint.fill"),
            .mock(id: "greetings", name: "Приветствия", order: 4, signCount: 12, icon: "hand.wave"),
            .mock(id: "numbers", name: "Числа", order: 5, signCount: 20, icon: "number"),
            .mock(id: "colors", name: "Цвета", order: 6, signCount: 15, icon: "paintpalette.fill")
        ]
    }
}
#endif

