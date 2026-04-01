import LINKER
import XCTest
@testable import BulletinBoard

final class StoreAnySignalTests: XCTestCase {

    private func makeStore() -> Store<AppState> {
        Store(
            initialState: AppState.initial,
            reducer: appReducer,
            middlewares: []
        )
    }

    func test_selectArticles_returnsAnySignal() {
        let store = makeStore()
        let signal: AnySignal<ArticleState> = store.selectArticles()
        XCTAssertEqual(signal.get(), AppState.initial.articles)
    }

    func test_selectFeeds_returnsAnySignal() {
        let store = makeStore()
        let signal: AnySignal<FeedState> = store.selectFeeds()
        XCTAssertEqual(signal.get(), AppState.initial.feeds)
    }

    func test_selectUI_returnsAnySignal() {
        let store = makeStore()
        let signal: AnySignal<UIState> = store.selectUI()
        XCTAssertEqual(signal.get(), AppState.initial.ui)
    }

    func test_selectTheme_returnsAnySignal() {
        let store = makeStore()
        let signal: AnySignal<BulletinBoard.Theme> = store.selectTheme()
        XCTAssertEqual(signal.get(), AppState.initial.ui.theme)
    }

    func test_selectArticles_updatesOnDispatch() {
        let store = makeStore()
        let signal: AnySignal<ArticleState> = store.selectArticles()

        store.dispatch(ArticleAction.setSearchQuery("test"))

        XCTAssertEqual(signal.get().searchQuery, "test")
    }

    func test_selectTheme_updatesOnDispatch() {
        let store = makeStore()
        let signal: AnySignal<BulletinBoard.Theme> = store.selectTheme()

        store.dispatch(UIAction.setTheme(.dark))

        XCTAssertEqual(signal.get(), .dark)
    }
}
