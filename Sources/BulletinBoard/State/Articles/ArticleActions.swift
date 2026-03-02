import Foundation
import LINKER

/// Actions for article state management
public enum ArticleAction: Action {
    // MARK: - Article CRUD
    case addArticles([Article])
    case updateArticle(id: String, Article)
    case removeArticle(id: String)
    case removeArticles([String])

    // MARK: - Article Operations
    case markAsRead(id: String)
    case markAllAsRead
    case toggleFavorite(id: String)
    case archiveArticle(id: String)
    case unarchiveArticle(id: String)

    // MARK: - NLP Updates
    case updateNLP(id: String, summary: String?, keywords: [String], category: ArticleCategory?, sentiment: Double?, cluster: Int?)
    case batchUpdateNLP([(id: String, summary: String?, keywords: [String], category: ArticleCategory?, sentiment: Double?, cluster: Int?)])

    // MARK: - Selection
    case selectArticle(id: String?)

    // MARK: - Search & Filter
    case setSearchQuery(String)
    case setFilters(ArticleFilters)
    case setSortOrder(ArticleSortOrder)
    case resetFilters

    // MARK: - Bulk Operations
    case markMultipleAsRead([String])
    case archiveMultiple([String])
    case deleteOlderThan(Date)
}
