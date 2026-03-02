import Foundation
import LINKER

/// Actions for feed state management
public enum FeedAction: Action {
    // MARK: - Feed CRUD
    case addFeed(Feed)
    case updateFeed(id: String, Feed)
    case removeFeed(id: String)

    // MARK: - Feed Operations
    case toggleFeedEnabled(id: String)
    case selectFeed(id: String?)

    // MARK: - Fetching
    case startFetching(id: String)
    case completeFetch(id: String, articleCount: Int)
    case failFetch(id: String, error: String)

    // MARK: - Unread Count
    case updateUnreadCount(feedId: String, count: Int)
    case recalculateAllUnreadCounts([String: Int]) // feedId -> count

    // MARK: - Batch Operations
    case refreshAllFeeds
}
