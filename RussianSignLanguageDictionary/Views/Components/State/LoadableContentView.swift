import SwiftUI

/// Обёртка над `ScreenLoadState`: показывает `LoadingView` для `.idle`/`.loading`,
/// переданный контент для `.loaded`, переданный `ErrorView` для `.error`.
///
/// `errorView` принимает готовую `ErrorView`, а не просто retry-closure,
/// т.к. разные экраны используют разные кнопки ошибки (`retryAction`/`skipAction`).
struct LoadableContentView<Content: View, ErrorContent: View>: View {
    let state: ScreenLoadState
    let loadingMessage: String
    @ViewBuilder let content: () -> Content
    let errorView: (String) -> ErrorContent

    var body: some View {
        switch state {
        case .idle, .loading:
            LoadingView(message: loadingMessage)
        case .loaded:
            content()
        case .error(let message):
            errorView(message)
        }
    }
}
