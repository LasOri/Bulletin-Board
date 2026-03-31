import LINKER

public enum AnimationPhase: String, Equatable, Sendable {
    case idle
    case expanding
    case expanded
    case collapsing
}

public struct UIState: Equatable, Sendable {
    public var expandedArticleId: String?

    public var isSidebarVisible: Bool

    public var isFeedManagerOpen: Bool

    public var isSettingsOpen: Bool

    public var theme: Theme

    public var animationPhase: AnimationPhase

    public var errorMessage: String?

    public var toastMessage: String?

    public var activeTab: String

    public init(
        expandedArticleId: String? = nil,
        isSidebarVisible: Bool = true,
        isFeedManagerOpen: Bool = false,
        isSettingsOpen: Bool = false,
        theme: Theme = .auto,
        animationPhase: AnimationPhase = .idle,
        errorMessage: String? = nil,
        toastMessage: String? = nil,
        activeTab: String = "news-feed"
    ) {
        self.expandedArticleId = expandedArticleId
        self.isSidebarVisible = isSidebarVisible
        self.isFeedManagerOpen = isFeedManagerOpen
        self.isSettingsOpen = isSettingsOpen
        self.theme = theme
        self.animationPhase = animationPhase
        self.errorMessage = errorMessage
        self.toastMessage = toastMessage
        self.activeTab = activeTab
    }
}

public enum Theme: String, CaseIterable, Sendable {
    case light = "Light"
    case dark = "Dark"
    case auto = "Auto"

    public func resolved(systemIsDark: Bool) -> Theme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .auto: return systemIsDark ? .dark : .light
        }
    }
}

extension UIState {
    public var isArticleExpanded: Bool {
        expandedArticleId != nil
    }

    public mutating func showError(_ message: String) {
        errorMessage = message
    }

    public mutating func clearError() {
        errorMessage = nil
    }

    public mutating func showToast(_ message: String) {
        toastMessage = message
    }

    public mutating func clearToast() {
        toastMessage = nil
    }

    public mutating func beginExpanding(_ id: String) {
        expandedArticleId = id
        animationPhase = .expanding
    }

    public mutating func expandComplete() {
        animationPhase = .expanded
    }

    public mutating func beginCollapsing() {
        animationPhase = .collapsing
    }

    public mutating func collapseComplete() {
        expandedArticleId = nil
        animationPhase = .idle
    }

    public mutating func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    public mutating func openFeedManager() {
        isFeedManagerOpen = true
    }

    public mutating func closeFeedManager() {
        isFeedManagerOpen = false
    }

    public mutating func toggleSettings() {
        isSettingsOpen.toggle()
    }

    public mutating func switchToTab(_ tab: String) {
        activeTab = tab
    }
}
