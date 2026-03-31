import LINKER

public let appStore: Store<AppState> = {
    let store = Store(
        initialState: AppState.initial,
        reducer: appReducer,
        middlewares: []
    )

    return store
}()

extension Store where State == AppState {
    public func selectArticles() -> any Signal<ArticleState> {
        select(\.articles)
    }

    public func selectFeeds() -> any Signal<FeedState> {
        select(\.feeds)
    }

    public func selectUI() -> any Signal<UIState> {
        select(\.ui)
    }

    public func selectTheme() -> any Signal<Theme> {
        select(\.ui.theme)
    }
}
