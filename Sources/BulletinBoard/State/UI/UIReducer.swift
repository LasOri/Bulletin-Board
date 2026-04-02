import LINKER

public func uiReducer(state: UIState, action: AnyAction) -> UIState {
    guard let action = action.as(UIAction.self) else {
        return state
    }

    var newState = state

    switch action {
    case .beginExpanding(let id):
        newState.beginExpanding(id)

    case .expandComplete:
        newState.expandComplete()

    case .beginCollapsing:
        newState.beginCollapsing()

    case .collapseComplete:
        newState.collapseComplete()

    case .openFeedManager:
        newState.openFeedManager()

    case .closeFeedManager:
        newState.closeFeedManager()

    case .toggleSettings:
        newState.toggleSettings()

    case .toggleSidebar:
        newState.toggleSidebar()

    case .showSidebar:
        newState.isSidebarVisible = true

    case .hideSidebar:
        newState.isSidebarVisible = false

    case .setTheme(let theme):
        newState.theme = theme

    case .showError(let message):
        newState.showError(message)

    case .clearError:
        newState.clearError()

    case .showToast(let message):
        newState.showToast(message)

    case .clearToast:
        newState.clearToast()

    case .switchTab(let tab):
        newState.switchToTab(tab)

    case .showConfirmation(let message, let pendingAction):
        newState.confirmationMessage = message
        newState.pendingAction = pendingAction

    case .cancelConfirmation:
        newState.confirmationMessage = nil
        newState.pendingAction = nil

    case .confirmAction:
        newState.confirmationMessage = nil
        newState.pendingAction = nil

    case .setViewMode(let mode):
        newState.viewMode = mode

    case .setOffline(let offline):
        newState.isOffline = offline
    }

    return newState
}
