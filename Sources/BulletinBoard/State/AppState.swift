import Foundation
import LINKER

public struct AppState: Codable, Equatable, Sendable {
    public var articles: ArticleState

    public var feeds: FeedState

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

    public static let initial = AppState()
}

