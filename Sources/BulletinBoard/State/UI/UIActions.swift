import Foundation
import LINKER

/// Actions for UI state management
public enum UIAction: Action {
    // MARK: - Article Expansion
    case beginExpanding(id: String)
    case expandComplete
    case beginCollapsing
    case collapseComplete

    // MARK: - Modals
    case openFeedManager
    case closeFeedManager
    case toggleSettings

    // MARK: - Sidebar
    case toggleSidebar
    case showSidebar
    case hideSidebar

    // MARK: - Theme
    case setTheme(Theme)

    // MARK: - Notifications
    case showError(String)
    case clearError
    case showToast(String)
    case clearToast

    // MARK: - Tabs
    case switchTab(String)
}
