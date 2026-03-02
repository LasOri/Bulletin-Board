import Foundation
import LINKER

/// Actions for UI state management
public enum UIAction: Action {
    // MARK: - Article Expansion
    case expandArticle(id: String)
    case collapseArticle
    case completeAnimation

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
}
