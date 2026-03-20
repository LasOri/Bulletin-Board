import Foundation
import LINKER

public struct ArticleColor: Codable, Equatable, Sendable {
    public let r: Float
    public let g: Float
    public let b: Float

    public init(r: Float, g: Float, b: Float) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public struct Article: Codable, Equatable, Identifiable, Sendable {
    public let id: String

    public let title: String

    public let description: String?

    public let content: String?

    public let url: String

    public let publishedAt: Date?

    public let author: String?

    public let feedId: String

    public let categories: [String]

    public let enclosure: ArticleEnclosure?

    public var isRead: Bool

    public var isFavorite: Bool

    public var isArchived: Bool

    public var nlpSummary: String?

    public var keywords: [String]

    public var autoCategory: ArticleCategory?

    public var sentimentScore: Double?

    public var clusterId: Int?

    public var dominantColor: ArticleColor?

    public let addedAt: Date

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
        dominantColor: ArticleColor? = nil,
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
        self.dominantColor = dominantColor
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }

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
        case .technology: return "#3b82f6"
        case .science: return "#10b981"
        case .politics: return "#ef4444"
        case .business: return "#f59e0b"
        case .health: return "#ec4899"
        case .entertainment: return "#8b5cf6"
        case .sports: return "#06b6d4"
        case .world: return "#6366f1"
        case .opinion: return "#f97316"
        case .lifestyle: return "#14b8a6"
        case .other: return "#6b7280"
        }
    }
}

extension Article {
    public var displayContent: String {
        nlpSummary ?? description ?? content ?? ""
    }

    public var textForNLP: String {
        [content, description, title]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    public var isNLPProcessed: Bool {
        nlpSummary != nil && !keywords.isEmpty
    }

    public var sentimentLabel: String? {
        guard let score = sentimentScore else { return nil }
        if score > 0.1 { return "Positive" }
        if score < -0.1 { return "Negative" }
        return "Neutral"
    }

    public mutating func markAsRead() {
        isRead = true
        updatedAt = Date()
    }

    public mutating func toggleFavorite() {
        isFavorite.toggle()
        updatedAt = Date()
    }

    public mutating func archive() {
        isArchived = true
        updatedAt = Date()
    }

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

    public mutating func updateDominantColor(_ color: ArticleColor) {
        self.dominantColor = color
        self.updatedAt = Date()
    }
}

