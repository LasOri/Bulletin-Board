import Foundation
import LINKER

/// Global application store
public let appStore: Store<AppState> = {
    let store = Store(
        initialState: AppState.initial,
        reducer: appReducer,
        middlewares: []
    )

    return store
}()

// MARK: - Store Extensions for Convenience

extension Store where State == AppState {
    /// Select articles state
    public func selectArticles() -> any Signal<ArticleState> {
        select(\.articles)
    }

    /// Select feeds state
    public func selectFeeds() -> any Signal<FeedState> {
        select(\.feeds)
    }

    /// Select UI state
    public func selectUI() -> any Signal<UIState> {
        select(\.ui)
    }

    /// Select theme
    public func selectTheme() -> any Signal<Theme> {
        select(\.ui.theme)
    }
}
