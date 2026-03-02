import Foundation
import LINKER

/// Represents an article from an RSS/Atom feed
public struct Article: Codable, Equatable, Identifiable, Sendable {
    /// Unique identifier (from RSS guid or link)
    public let id: String

    /// Article title
    public let title: String

    /// Short description/summary
    public let description: String?

    /// Full HTML content (if available)
    public let content: String?

    /// Article URL
    public let url: String

    /// Publication date
    public let publishedAt: Date?

    /// Author name
    public let author: String?

    /// Source feed ID
    public let feedId: String

    /// Categories/tags from feed
    public let categories: [String]

    /// Media enclosure (podcast, image)
    public let enclosure: ArticleEnclosure?

    /// Read status
    public var isRead: Bool

    /// Favorite/bookmark status
    public var isFavorite: Bool

    /// Archived status
    public var isArchived: Bool

    /// NLP-generated summary (if processed)
    public var nlpSummary: String?

    /// NLP-extracted keywords
    public var keywords: [String]

    /// Auto-assigned category
    public var autoCategory: ArticleCategory?

    /// Sentiment score (-1.0 to 1.0)
    public var sentimentScore: Double?

    /// Cluster ID for related articles
    public var clusterId: Int?

    /// When article was added to local storage
    public let addedAt: Date

    /// When article was last modified
    public var updatedAt: Date

    public init(
        id: String,
        title: String,
        description: String? = nil,
        content: String? = nil,
        url: String,
        publishedAt: Date? = nil,
        author: String? = nil,
        feedId: String,
        categories: [String] = [],
        enclosure: ArticleEnclosure? = nil,
        isRead: Bool = false,
        isFavorite: Bool = false,
        isArchived: Bool = false,
        nlpSummary: String? = nil,
        keywords: [String] = [],
        autoCategory: ArticleCategory? = nil,
        sentimentScore: Double? = nil,
        clusterId: Int? = nil,
        addedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.content = content
        self.url = url
        self.publishedAt = publishedAt
        self.author = author
        self.feedId = feedId
        self.categories = categories
        self.enclosure = enclosure
        self.isRead = isRead
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.nlpSummary = nlpSummary
        self.keywords = keywords
        self.autoCategory = autoCategory
        self.sentimentScore = sentimentScore
        self.clusterId = clusterId
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }

    /// Create Article from RSSItem
    public static func from(rssItem: RSSItem, feedId: String) -> Article {
        Article(
            id: rssItem.id,
            title: rssItem.title,
            description: rssItem.description,
            content: rssItem.content,
            url: rssItem.link,
            publishedAt: rssItem.pubDate,
            author: rssItem.author,
            feedId: feedId,
            categories: rssItem.categories,
            enclosure: rssItem.enclosure.map { ArticleEnclosure(url: $0.url, type: $0.type, length: $0.length) }
        )
    }
}

/// Media enclosure for articles
public struct ArticleEnclosure: Codable, Equatable, Sendable {
    public let url: String
    public let type: String
    public let length: Int?

    public init(url: String, type: String, length: Int? = nil) {
        self.url = url
        self.type = type
        self.length = length
    }
}

/// Article categories (auto-assigned by NLP)
public enum ArticleCategory: String, Codable, CaseIterable, Sendable {
    case technology = "Technology"
    case science = "Science"
    case politics = "Politics"
    case business = "Business"
    case health = "Health"
    case entertainment = "Entertainment"
    case sports = "Sports"
    case world = "World"
    case opinion = "Opinion"
    case lifestyle = "Lifestyle"
    case other = "Other"

    public var color: String {
        switch self {
        case .technology: return "#3b82f6"    // blue
        case .science: return "#10b981"       // green
        case .politics: return "#ef4444"      // red
        case .business: return "#f59e0b"      // amber
        case .health: return "#ec4899"        // pink
        case .entertainment: return "#8b5cf6" // purple
        case .sports: return "#06b6d4"        // cyan
        case .world: return "#6366f1"         // indigo
        case .opinion: return "#f97316"       // orange
        case .lifestyle: return "#14b8a6"     // teal
        case .other: return "#6b7280"         // gray
        }
    }
}

// MARK: - Article Extensions

extension Article {
    /// Get the best available text content for display
    public var displayContent: String {
        nlpSummary ?? description ?? content ?? ""
    }

    /// Get the best available text for NLP processing
    public var textForNLP: String {
        [content, description, title]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    /// Check if article has been processed by NLP
    public var isNLPProcessed: Bool {
        nlpSummary != nil && !keywords.isEmpty
    }

    /// Mark as read
    public mutating func markAsRead() {
        isRead = true
        updatedAt = Date()
    }

    /// Toggle favorite status
    public mutating func toggleFavorite() {
        isFavorite.toggle()
        updatedAt = Date()
    }

    /// Archive article
    public mutating func archive() {
        isArchived = true
        updatedAt = Date()
    }

    /// Update NLP results
    public mutating func updateNLP(
        summary: String?,
        keywords: [String],
        category: ArticleCategory?,
        sentiment: Double?,
        cluster: Int?
    ) {
        self.nlpSummary = summary
        self.keywords = keywords
        self.autoCategory = category
        self.sentimentScore = sentiment
        self.clusterId = cluster
        self.updatedAt = Date()
    }
}
