import LINKER

public enum FeedAction: Action {
    case addFeed(Feed)
    case updateFeed(id: String, Feed)
    case removeFeed(id: String)

    case toggleFeedEnabled(id: String)
    case selectFeed(id: String?)

    case startFetching(id: String)
    case completeFetch(id: String, articleCount: Int)
    case failFetch(id: String, error: String)

    case updateUnreadCount(feedId: String, count: Int)
    case recalculateAllUnreadCounts([String: Int])

    case refreshAllFeeds
}
