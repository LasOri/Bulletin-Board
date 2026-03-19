import Foundation

public enum FeedType: String, Sendable {
    case rss
    case atom
    case unknown
}

public struct DiscoveredFeed: Sendable {
    public let url: String
    public let title: String?
    public let type: FeedType

    public init(url: String, title: String? = nil, type: FeedType = .unknown) {
        self.url = url
        self.title = title
        self.type = type
    }
}
