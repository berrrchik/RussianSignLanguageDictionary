import Foundation

/// Общее состояние загрузки экрана: используется ViewModel'ами, у которых
/// весь загруженный контент лежит в отдельном `@Published`-свойстве,
/// а этот enum описывает только фазу загрузки.
enum ScreenLoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}
