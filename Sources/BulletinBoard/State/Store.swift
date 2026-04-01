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
    public func selectArticles() -> AnySignal<ArticleState> {
        select(\.articles)
    }

    public func selectFeeds() -> AnySignal<FeedState> {
        select(\.feeds)
    }

    public func selectUI() -> AnySignal<UIState> {
        select(\.ui)
    }

    public func selectTheme() -> AnySignal<Theme> {
        select(\.ui.theme)
    }
}
