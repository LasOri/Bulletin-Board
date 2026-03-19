import Foundation
import LINKER

public struct ArticleState: Codable, Equatable, Sendable {
    public var byId: [String: Article]

    public var allIds: [String]

    public var selectedId: String?

    public var searchQuery: String

    public var searchResults: [SearchResult]?

    public var filters: ArticleFilters

    public var sortBy: ArticleSortOrder

    public init(
        byId: [String: Article] = [:],
        allIds: [String] = [],
        selectedId: String? = nil,
        searchQuery: String = "",
        searchResults: [SearchResult]? = nil,
        filters: ArticleFilters = ArticleFilters(),
        sortBy: ArticleSortOrder = .newest
    ) {
        self.byId = byId
        self.allIds = allIds
        self.selectedId = selectedId
        self.searchQuery = searchQuery
        self.searchResults = searchResults
        self.filters = filters
        self.sortBy = sortBy
    }
}

public struct SearchResult: Codable, Equatable, Sendable {
    public let articleId: String
    public let score: Double
    public let matchedFields: Set<String>

    public init(articleId: String, score: Double, matchedFields: Set<String>) {
        self.articleId = articleId
        self.score = score
        self.matchedFields = matchedFields
    }
}

public struct ArticleFilters: Codable, Equatable, Sendable {
    public var feedIds: Set<String>

    public var categories: Set<ArticleCategory>

    public var showOnlyUnread: Bool

    public var showOnlyFavorites: Bool

    public var showArchived: Bool

    public var dateRange: DateRange?

    public init(
        feedIds: Set<String> = [],
        categories: Set<ArticleCategory> = [],
        showOnlyUnread: Bool = false,
        showOnlyFavorites: Bool = false,
        showArchived: Bool = false,
        dateRange: DateRange? = nil
    ) {
        self.feedIds = feedIds
        self.categories = categories
        self.showOnlyUnread = showOnlyUnread
        self.showOnlyFavorites = showOnlyFavorites
        self.showArchived = showArchived
        self.dateRange = dateRange
    }

    public var isActive: Bool {
        !feedIds.isEmpty ||
        !categories.isEmpty ||
        showOnlyUnread ||
        showOnlyFavorites ||
        dateRange != nil
    }

    public mutating func reset() {
        feedIds.removeAll()
        categories.removeAll()
        showOnlyUnread = false
        showOnlyFavorites = false
        showArchived = false
        dateRange = nil
    }
}

public enum DateRange: Codable, Equatable, Sendable {
    case today
    case lastWeek
    case lastMonth
    case custom(start: Date, end: Date)

    public var dateInterval: DateInterval {
        let now = Date()
        let calendar = Calendar.current

        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return DateInterval(start: startOfDay, end: now)

        case .lastWeek:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return DateInterval(start: weekAgo, end: now)

        case .lastMonth:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return DateInterval(start: monthAgo, end: now)

        case .custom(let start, let end):
            return DateInterval(start: start, end: end)
        }
    }
}

public enum ArticleSortOrder: String, Codable, CaseIterable, Sendable {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case title = "Title (A-Z)"
    case feed = "By Feed"
    case category = "By Category"
}

extension ArticleState {
    public var articles: [Article] {
        allIds.compactMap { byId[$0] }
    }

    public var selectedArticle: Article? {
        guard let id = selectedId else { return nil }
        return byId[id]
    }

    public var filteredArticles: [Article] {
        var result = articles

        if !searchQuery.isEmpty, let searchResults = searchResults {
            let rankedIds = searchResults.map { $0.articleId }
            let rankedArticles = rankedIds.compactMap { byId[$0] }
            result = rankedArticles
        } else if !searchQuery.isEmpty {
            result = result.filter { article in
                article.title.localizedCaseInsensitiveContains(searchQuery) ||
                article.description?.localizedCaseInsensitiveContains(searchQuery) == true ||
                article.keywords.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
            }
        }

        if filters.isActive {
            result = result.filter { article in
                if !filters.feedIds.isEmpty && !filters.feedIds.contains(article.feedId) {
                    return false
                }

                if !filters.categories.isEmpty {
                    guard let category = article.autoCategory,
                          filters.categories.contains(category) else {
                        return false
                    }
                }

                if filters.showOnlyUnread && article.isRead {
                    return false
                }

                if filters.showOnlyFavorites && !article.isFavorite {
                    return false
                }

                if !filters.showArchived && article.isArchived {
                    return false
                }

                if let dateRange = filters.dateRange,
                   let publishedAt = article.publishedAt,
                   !dateRange.dateInterval.contains(publishedAt) {
                    return false
                }

                return true
            }
        } else {
            result = result.filter { !$0.isArchived }
        }

        switch sortBy {
        case .newest:
            result.sort { ($0.publishedAt ?? $0.addedAt) > ($1.publishedAt ?? $1.addedAt) }
        case .oldest:
            result.sort { ($0.publishedAt ?? $0.addedAt) < ($1.publishedAt ?? $1.addedAt) }
        case .title:
            result.sort { $0.title < $1.title }
        case .feed:
            result.sort { $0.feedId < $1.feedId }
        case .category:
            result.sort { ($0.autoCategory?.rawValue ?? "") < ($1.autoCategory?.rawValue ?? "") }
        }

        return result
    }

    public var unreadCount: Int {
        articles.filter { !$0.isRead && !$0.isArchived }.count
    }

    public var favoriteCount: Int {
        articles.filter { $0.isFavorite }.count
    }

    public var categoryCounts: [(category: ArticleCategory, count: Int)] {
        var counts: [ArticleCategory: Int] = [:]
        for article in articles where !article.isArchived {
            if let cat = article.autoCategory {
                counts[cat, default: 0] += 1
            }
        }
        return ArticleCategory.allCases.compactMap { cat in
            guard let count = counts[cat], count > 0 else { return nil }
            return (category: cat, count: count)
        }
    }
}

