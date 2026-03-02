import Foundation
import LINKER

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

    /// Is expansion animation in progress
    public var isAnimating: Bool

    /// Last error message to display
    public var errorMessage: String?

    /// Toast notification message
    public var toastMessage: String?

    public init(
        expandedArticleId: String? = nil,
        isSidebarVisible: Bool = true,
        isFeedManagerOpen: Bool = false,
        isSettingsOpen: Bool = false,
        theme: Theme = .auto,
        isAnimating: Bool = false,
        errorMessage: String? = nil,
        toastMessage: String? = nil
    ) {
        self.expandedArticleId = expandedArticleId
        self.isSidebarVisible = isSidebarVisible
        self.isFeedManagerOpen = isFeedManagerOpen
        self.isSettingsOpen = isSettingsOpen
        self.theme = theme
        self.isAnimating = isAnimating
        self.errorMessage = errorMessage
        self.toastMessage = toastMessage
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

    /// Expand article
    public mutating func expandArticle(_ id: String) {
        expandedArticleId = id
        isAnimating = true
    }

    /// Collapse article
    public mutating func collapseArticle() {
        expandedArticleId = nil
        isAnimating = true
    }

    /// Animation complete
    public mutating func completeAnimation() {
        isAnimating = false
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
}
