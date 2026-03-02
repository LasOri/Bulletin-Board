import Foundation
import LINKER

/// Represents an RSS/Atom feed subscription
public struct Feed: Codable, Equatable, Identifiable, Sendable {
    /// Unique identifier (generated UUID)
    public let id: String

    /// Feed title
    public let title: String

    /// Feed description
    public let description: String

    /// Feed URL (RSS/Atom endpoint)
    public let url: String

    /// Website URL
    public let siteUrl: String?

    /// Feed language
    public let language: String?

    /// Feed icon/favicon URL
    public var iconUrl: String?

    /// User-defined category
    public var userCategory: String?

    /// Feed update frequency (minutes)
    public var updateFrequency: Int

    /// Last fetch date
    public var lastFetched: Date?

    /// Last successful fetch date
    public var lastSuccessfulFetch: Date?

    /// Last error message (if any)
    public var lastError: String?

    /// Number of articles fetched
    public var articleCount: Int

    /// Number of unread articles
    public var unreadCount: Int

    /// Subscription date
    public let subscribedAt: Date

    /// Last modified date
    public var updatedAt: Date

    /// Is feed enabled (fetching active)
    public var isEnabled: Bool

    /// Is feed currently fetching
    public var isFetching: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        url: String,
        siteUrl: String? = nil,
        language: String? = nil,
        iconUrl: String? = nil,
        userCategory: String? = nil,
        updateFrequency: Int = 60,
        lastFetched: Date? = nil,
        lastSuccessfulFetch: Date? = nil,
        lastError: String? = nil,
        articleCount: Int = 0,
        unreadCount: Int = 0,
        subscribedAt: Date = Date(),
        updatedAt: Date = Date(),
        isEnabled: Bool = true,
        isFetching: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.url = url
        self.siteUrl = siteUrl
        self.language = language
        self.iconUrl = iconUrl
        self.userCategory = userCategory
        self.updateFrequency = updateFrequency
        self.lastFetched = lastFetched
        self.lastSuccessfulFetch = lastSuccessfulFetch
        self.lastError = lastError
        self.articleCount = articleCount
        self.unreadCount = unreadCount
        self.subscribedAt = subscribedAt
        self.updatedAt = updatedAt
        self.isEnabled = isEnabled
        self.isFetching = isFetching
    }

    /// Create Feed from RSSFeed
    public static func from(rssFeed: RSSFeed, url: String) -> Feed {
        Feed(
            title: rssFeed.title,
            description: rssFeed.description,
            url: url,
            siteUrl: rssFeed.link,
            language: rssFeed.language
        )
    }
}

// MARK: - Feed Extensions

extension Feed {
    /// Check if feed needs update
    public func needsUpdate() -> Bool {
        guard isEnabled else { return false }

        guard let lastFetch = lastFetched else {
            return true // Never fetched
        }

        let interval = TimeInterval(updateFrequency * 60)
        return Date().timeIntervalSince(lastFetch) >= interval
    }

    /// Mark fetch started
    public mutating func startFetching() {
        isFetching = true
        lastFetched = Date()
        updatedAt = Date()
    }

    /// Mark fetch completed successfully
    public mutating func completeFetch(articleCount: Int) {
        isFetching = false
        lastSuccessfulFetch = Date()
        lastError = nil
        self.articleCount = articleCount
        updatedAt = Date()
    }

    /// Mark fetch failed
    public mutating func failFetch(error: String) {
        isFetching = false
        lastError = error
        updatedAt = Date()
    }

    /// Update unread count
    public mutating func updateUnreadCount(_ count: Int) {
        unreadCount = count
        updatedAt = Date()
    }

    /// Toggle enabled status
    public mutating func toggleEnabled() {
        isEnabled.toggle()
        updatedAt = Date()
    }
}
