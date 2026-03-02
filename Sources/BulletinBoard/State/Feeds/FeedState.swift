import Foundation
import LINKER

/// State for feed subscriptions
public struct FeedState: Codable, Equatable, Sendable {
    /// All feeds by ID
    public var byId: [String: Feed]

    /// Feed IDs in subscription order
    public var allIds: [String]

    /// Currently selected feed ID (for filtering)
    public var selectedId: String?

    /// Feeds currently being fetched
    public var fetchingIds: Set<String>

    public init(
        byId: [String: Feed] = [:],
        allIds: [String] = [],
        selectedId: String? = nil,
        fetchingIds: Set<String> = []
    ) {
        self.byId = byId
        self.allIds = allIds
        self.selectedId = selectedId
        self.fetchingIds = fetchingIds
    }
}

// MARK: - FeedState Extensions

extension FeedState {
    /// Get all feeds as array
    public var feeds: [Feed] {
        allIds.compactMap { byId[$0] }
    }

    /// Get selected feed
    public var selectedFeed: Feed? {
        guard let id = selectedId else { return nil }
        return byId[id]
    }

    /// Get enabled feeds
    public var enabledFeeds: [Feed] {
        feeds.filter { $0.isEnabled }
    }

    /// Get feeds that need updating
    public var feedsNeedingUpdate: [Feed] {
        enabledFeeds.filter { $0.needsUpdate() && !fetchingIds.contains($0.id) }
    }

    /// Total unread count across all feeds
    public var totalUnreadCount: Int {
        feeds.reduce(0) { $0 + $1.unreadCount }
    }

    /// Get feed by URL
    public func feedByURL(_ url: String) -> Feed? {
        feeds.first { $0.url == url }
    }

    /// Check if feed exists
    public func hasFeed(url: String) -> Bool {
        feedByURL(url) != nil
    }

    /// Check if feed is currently fetching
    public func isFetching(_ feedId: String) -> Bool {
        fetchingIds.contains(feedId)
    }
}
