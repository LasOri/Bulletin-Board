import Foundation
import LINKER

/// Reducer for UI state
public func uiReducer(state: UIState, action: any Action) -> UIState {
    guard let action = action as? UIAction else {
        return state
    }

    var newState = state

    switch action {
    // MARK: - Article Expansion
    case .expandArticle(let id):
        newState.expandArticle(id)

    case .collapseArticle:
        newState.collapseArticle()

    case .completeAnimation:
        newState.completeAnimation()

    // MARK: - Modals
    case .openFeedManager:
        newState.openFeedManager()

    case .closeFeedManager:
        newState.closeFeedManager()

    case .toggleSettings:
        newState.toggleSettings()

    // MARK: - Sidebar
    case .toggleSidebar:
        newState.toggleSidebar()

    case .showSidebar:
        newState.isSidebarVisible = true

    case .hideSidebar:
        newState.isSidebarVisible = false

    // MARK: - Theme
    case .setTheme(let theme):
        newState.theme = theme

    // MARK: - Notifications
    case .showError(let message):
        newState.showError(message)

    case .clearError:
        newState.clearError()

    case .showToast(let message):
        newState.showToast(message)

    case .clearToast:
        newState.clearToast()
    }

    return newState
}
