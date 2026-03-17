import Foundation
import LINKER

/// Phase of card expansion/collapse animation
public enum AnimationPhase: String, Codable, Equatable, Sendable {
    /// No animation — article list visible
    case idle
    /// Clone animating from card rect to fullscreen
    case expanding
    /// Detail view rendered by reconciler (resting state)
    case expanded
    /// Clone animating from fullscreen back to card rect
    case collapsing
}

/// UI state for app-level UI concerns
public struct UIState: Codable, Equatable, Sendable {
    /// Currently expanded article ID (for detail view)
    public var expandedArticleId: String?

    /// Is sidebar visible (on mobile/tablet)
    public var isSidebarVisible: Bool

    /// Is feed manager modal open
    public var isFeedManagerOpen: Bool

    /// Is settings modal open
    public var isSettingsOpen: Bool

    /// Current theme
    public var theme: Theme

    /// Current phase of the card expansion animation
    public var animationPhase: AnimationPhase

    /// Last error message to display
    public var errorMessage: String?

    /// Toast notification message
    public var toastMessage: String?

    /// Active tab (webgpu-test or news-feed)
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

/// Theme options
public enum Theme: String, Codable, CaseIterable, Sendable {
    case light = "Light"
    case dark = "Dark"
    case auto = "Auto"

    /// Get actual theme accounting for system preference
    public func resolved(systemIsDark: Bool) -> Theme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .auto: return systemIsDark ? .dark : .light
        }
    }
}

// MARK: - UIState Extensions

extension UIState {
    /// Check if article detail is expanded
    public var isArticleExpanded: Bool {
        expandedArticleId != nil
    }

    /// Show error
    public mutating func showError(_ message: String) {
        errorMessage = message
    }

    /// Clear error
    public mutating func clearError() {
        errorMessage = nil
    }

    /// Show toast
    public mutating func showToast(_ message: String) {
        toastMessage = message
    }

    /// Clear toast
    public mutating func clearToast() {
        toastMessage = nil
    }

    /// Begin expanding article (clone animation phase)
    public mutating func beginExpanding(_ id: String) {
        expandedArticleId = id
        animationPhase = .expanding
    }

    /// Expand animation complete — reconciler renders detail view
    public mutating func expandComplete() {
        animationPhase = .expanded
    }

    /// Begin collapsing (clone animation phase)
    public mutating func beginCollapsing() {
        animationPhase = .collapsing
    }

    /// Collapse animation complete — back to idle
    public mutating func collapseComplete() {
        expandedArticleId = nil
        animationPhase = .idle
    }

    /// Toggle sidebar
    public mutating func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    /// Open feed manager
    public mutating func openFeedManager() {
        isFeedManagerOpen = true
    }

    /// Close feed manager
    public mutating func closeFeedManager() {
        isFeedManagerOpen = false
    }

    /// Toggle settings
    public mutating func toggleSettings() {
        isSettingsOpen.toggle()
    }

    /// Switch to tab
    public mutating func switchToTab(_ tab: String) {
        activeTab = tab
    }
}
