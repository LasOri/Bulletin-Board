import Foundation
import LINKER

/// Root application state
public struct AppState: Codable, Equatable, Sendable {
    /// Articles state
    public var articles: ArticleState

    /// Feeds state
    public var feeds: FeedState

    /// UI state
    public var ui: UIState

    public init(
        articles: ArticleState = ArticleState(),
        feeds: FeedState = FeedState(),
        ui: UIState = UIState()
    ) {
        self.articles = articles
        self.feeds = feeds
        self.ui = ui
    }

    /// Create initial empty state
    public static let initial = AppState()
}
