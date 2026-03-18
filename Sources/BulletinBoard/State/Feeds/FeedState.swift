import Foundation
import LINKER

public struct FeedState: Codable, Equatable, Sendable {
    public var byId: [String: Feed]

    public var allIds: [String]

    public var selectedId: String?

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

extension FeedState {
    public var feeds: [Feed] {
        allIds.compactMap { byId[$0] }
    }

    public var selectedFeed: Feed? {
        guard let id = selectedId else { return nil }
        return byId[id]
    }

    public var enabledFeeds: [Feed] {
        feeds.filter { $0.isEnabled }
    }

    public var feedsNeedingUpdate: [Feed] {
        enabledFeeds.filter { $0.needsUpdate() && !fetchingIds.contains($0.id) }
    }

    public var totalUnreadCount: Int {
        feeds.reduce(0) { $0 + $1.unreadCount }
    }

    public func feedByURL(_ url: String) -> Feed? {
        feeds.first { $0.url == url }
    }

    public func hasFeed(url: String) -> Bool {
        feedByURL(url) != nil
    }

    public func isFetching(_ feedId: String) -> Bool {
        fetchingIds.contains(feedId)
    }
}

