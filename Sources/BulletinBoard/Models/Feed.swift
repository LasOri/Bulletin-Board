import Foundation
import LINKER

public struct Feed: Codable, Equatable, Identifiable, Sendable {
    public let id: String

    public let title: String

    public let description: String

    public let url: String

    public let siteUrl: String?

    public let language: String?

    public var iconUrl: String?

    public var userCategory: String?

    public var updateFrequency: Int

    public var lastFetched: Date?

    public var lastSuccessfulFetch: Date?

    public var lastError: String?

    public var articleCount: Int

    public var unreadCount: Int

    public let subscribedAt: Date

    public var updatedAt: Date

    public var isEnabled: Bool

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

extension Feed {
    public func needsUpdate() -> Bool {
        guard isEnabled else { return false }

        guard let lastFetch = lastFetched else {
            return true
        }

        let interval = TimeInterval(updateFrequency * 60)
        return Date().timeIntervalSince(lastFetch) >= interval
    }

    public mutating func startFetching() {
        isFetching = true
        lastFetched = Date()
        updatedAt = Date()
    }

    public mutating func completeFetch(articleCount: Int) {
        isFetching = false
        lastSuccessfulFetch = Date()
        lastError = nil
        self.articleCount = articleCount
        updatedAt = Date()
    }

    public mutating func failFetch(error: String) {
        isFetching = false
        lastError = error
        updatedAt = Date()
    }

    public mutating func updateUnreadCount(_ count: Int) {
        unreadCount = count
        updatedAt = Date()
    }

    public mutating func toggleEnabled() {
        isEnabled.toggle()
        updatedAt = Date()
    }
}

