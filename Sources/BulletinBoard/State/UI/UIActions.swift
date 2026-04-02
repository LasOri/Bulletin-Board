import LINKER

public enum UIAction: Action {
    case beginExpanding(id: String)
    case expandComplete
    case beginCollapsing
    case collapseComplete

    case openFeedManager
    case closeFeedManager
    case toggleSettings

    case toggleSidebar
    case showSidebar
    case hideSidebar

    case setTheme(Theme)

    case showError(String)
    case clearError
    case showToast(String)
    case clearToast

    case switchTab(String)

    case showConfirmation(message: String, pendingAction: String)
    case cancelConfirmation
    case confirmAction

    case setViewMode(ViewMode)
    case setOffline(Bool)
}
