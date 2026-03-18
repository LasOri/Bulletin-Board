import Foundation
import LINKER

public enum ArticleAction: Action {
    case addArticles([Article])
    case updateArticle(id: String, Article)
    case removeArticle(id: String)
    case removeArticles([String])

    case markAsRead(id: String)
    case markAllAsRead
    case toggleFavorite(id: String)
    case archiveArticle(id: String)
    case unarchiveArticle(id: String)

    case updateNLP(id: String, summary: String?, keywords: [String], category: ArticleCategory?, sentiment: Double?, cluster: Int?)
    case batchUpdateNLP([(id: String, summary: String?, keywords: [String], category: ArticleCategory?, sentiment: Double?, cluster: Int?)])

    case batchUpdateDominantColors([(id: String, color: ArticleColor)])

    case selectArticle(id: String?)

    case setSearchQuery(String)
    case setFilters(ArticleFilters)
    case setSortOrder(ArticleSortOrder)
    case resetFilters

    case markMultipleAsRead([String])
    case archiveMultiple([String])
    case deleteOlderThan(Date)
}

