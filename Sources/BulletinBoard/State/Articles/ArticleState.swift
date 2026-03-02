import Foundation
import LINKER

/// State for articles
public struct ArticleState: Codable, Equatable, Sendable {
    /// All articles by ID
    public var byId: [String: Article]

    /// Article IDs in chronological order (newest first)
    public var allIds: [String]

    /// Currently selected article ID
    public var selectedId: String?

    /// Search query
    public var searchQuery: String

    /// Active filters
    public var filters: ArticleFilters

    /// Sort order
    public var sortBy: ArticleSortOrder

    public init(
        byId: [String: Article] = [:],
        allIds: [String] = [],
        selectedId: String? = nil,
        searchQuery: String = "",
        filters: ArticleFilters = ArticleFilters(),
        sortBy: ArticleSortOrder = .newest
    ) {
        self.byId = byId
        self.allIds = allIds
        self.selectedId = selectedId
        self.searchQuery = searchQuery
        self.filters = filters
        self.sortBy = sortBy
    }
}

/// Article filtering options
public struct ArticleFilters: Codable, Equatable, Sendable {
    /// Filter by feed IDs (empty = all feeds)
    public var feedIds: Set<String>

    /// Filter by categories
    public var categories: Set<ArticleCategory>

    /// Show only unread
    public var showOnlyUnread: Bool

    /// Show only favorites
    public var showOnlyFavorites: Bool

    /// Show archived
    public var showArchived: Bool

    /// Date range
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

    /// Check if filters are active
    public var isActive: Bool {
        !feedIds.isEmpty ||
        !categories.isEmpty ||
        showOnlyUnread ||
        showOnlyFavorites ||
        dateRange != nil
    }

    /// Reset all filters
    public mutating func reset() {
        feedIds.removeAll()
        categories.removeAll()
        showOnlyUnread = false
        showOnlyFavorites = false
        showArchived = false
        dateRange = nil
    }
}

/// Date range filter
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

/// Article sort order
public enum ArticleSortOrder: String, Codable, CaseIterable, Sendable {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case title = "Title (A-Z)"
    case feed = "By Feed"
    case category = "By Category"
}

// MARK: - ArticleState Extensions

extension ArticleState {
    /// Get all articles as array
    public var articles: [Article] {
        allIds.compactMap { byId[$0] }
    }

    /// Get selected article
    public var selectedArticle: Article? {
        guard let id = selectedId else { return nil }
        return byId[id]
    }

    /// Get filtered and sorted articles
    public var filteredArticles: [Article] {
        var result = articles

        // Apply search
        if !searchQuery.isEmpty {
            result = result.filter { article in
                article.title.localizedCaseInsensitiveContains(searchQuery) ||
                article.description?.localizedCaseInsensitiveContains(searchQuery) == true ||
                article.keywords.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
            }
        }

        // Apply filters
        if filters.isActive {
            result = result.filter { article in
                // Feed filter
                if !filters.feedIds.isEmpty && !filters.feedIds.contains(article.feedId) {
                    return false
                }

                // Category filter
                if !filters.categories.isEmpty,
                   let category = article.autoCategory,
                   !filters.categories.contains(category) {
                    return false
                }

                // Unread filter
                if filters.showOnlyUnread && article.isRead {
                    return false
                }

                // Favorites filter
                if filters.showOnlyFavorites && !article.isFavorite {
                    return false
                }

                // Archived filter
                if !filters.showArchived && article.isArchived {
                    return false
                }

                // Date range filter
                if let dateRange = filters.dateRange,
                   let publishedAt = article.publishedAt,
                   !dateRange.dateInterval.contains(publishedAt) {
                    return false
                }

                return true
            }
        } else {
            // Default: hide archived
            result = result.filter { !$0.isArchived }
        }

        // Apply sort
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

    /// Get unread count
    public var unreadCount: Int {
        articles.filter { !$0.isRead && !$0.isArchived }.count
    }

    /// Get favorite count
    public var favoriteCount: Int {
        articles.filter { $0.isFavorite }.count
    }
}
