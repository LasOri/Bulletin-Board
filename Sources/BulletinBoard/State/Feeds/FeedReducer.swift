import Foundation
import LINKER

/// Reducer for feed state
public func feedReducer(state: FeedState, action: any Action) -> FeedState {
    guard let action = action as? FeedAction else {
        return state
    }

    var newState = state

    switch action {
    // MARK: - Feed CRUD
    case .addFeed(let feed):
        // Avoid duplicates
        if newState.byId[feed.id] == nil {
            newState.byId[feed.id] = feed
            newState.allIds.append(feed.id)
        }

    case .updateFeed(let id, let feed):
        newState.byId[id] = feed

    case .removeFeed(let id):
        newState.byId.removeValue(forKey: id)
        newState.allIds.removeAll { $0 == id }
        newState.fetchingIds.remove(id)
        if newState.selectedId == id {
            newState.selectedId = nil
        }

    // MARK: - Feed Operations
    case .toggleFeedEnabled(let id):
        if var feed = newState.byId[id] {
            feed.toggleEnabled()
            newState.byId[id] = feed
        }

    case .selectFeed(let id):
        newState.selectedId = id

    // MARK: - Fetching
    case .startFetching(let id):
        newState.fetchingIds.insert(id)
        if var feed = newState.byId[id] {
            feed.startFetching()
            newState.byId[id] = feed
        }

    case .completeFetch(let id, let articleCount):
        newState.fetchingIds.remove(id)
        if var feed = newState.byId[id] {
            feed.completeFetch(articleCount: articleCount)
            newState.byId[id] = feed
        }

    case .failFetch(let id, let error):
        newState.fetchingIds.remove(id)
        if var feed = newState.byId[id] {
            feed.failFetch(error: error)
            newState.byId[id] = feed
        }

    // MARK: - Unread Count
    case .updateUnreadCount(let feedId, let count):
        if var feed = newState.byId[feedId] {
            feed.updateUnreadCount(count)
            newState.byId[feedId] = feed
        }

    case .recalculateAllUnreadCounts(let counts):
        for (feedId, count) in counts {
            if var feed = newState.byId[feedId] {
                feed.updateUnreadCount(count)
                newState.byId[feedId] = feed
            }
        }

    // MARK: - Batch Operations
    case .refreshAllFeeds:
        // Mark all enabled feeds as needing refresh
        // Actual fetching happens in middleware/effects
        break
    }

    return newState
}
