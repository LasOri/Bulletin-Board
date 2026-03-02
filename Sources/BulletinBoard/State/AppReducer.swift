import Foundation
import LINKER

/// Root reducer combining all sub-reducers
public func appReducer(state: AppState, action: any Action) -> AppState {
    AppState(
        articles: articleReducer(state: state.articles, action: action),
        feeds: feedReducer(state: state.feeds, action: action),
        ui: uiReducer(state: state.ui, action: action)
    )
}
