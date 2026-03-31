import LINKER

public func feedReducer(state: FeedState, action: AnyAction) -> FeedState {
    guard let action = action.as(FeedAction.self) else {
        return state
    }

    var newState = state

    switch action {
    case .addFeed(let feed):
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

    case .toggleFeedEnabled(let id):
        if var feed = newState.byId[id] {
            feed.toggleEnabled()
            newState.byId[id] = feed
        }

    case .selectFeed(let id):
        newState.selectedId = id

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

    case .refreshAllFeeds:
        break
    }

    return newState
}
