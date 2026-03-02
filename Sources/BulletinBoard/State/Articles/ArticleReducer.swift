import Foundation
import LINKER

/// Reducer for article state
public func articleReducer(state: ArticleState, action: any Action) -> ArticleState {
    guard let action = action as? ArticleAction else {
        return state
    }

    var newState = state

    switch action {
    // MARK: - Article CRUD
    case .addArticles(let articles):
        for article in articles {
            // Avoid duplicates
            if newState.byId[article.id] == nil {
                newState.byId[article.id] = article
                newState.allIds.append(article.id)
            }
        }

    case .updateArticle(let id, let article):
        newState.byId[id] = article

    case .removeArticle(let id):
        newState.byId.removeValue(forKey: id)
        newState.allIds.removeAll { $0 == id }
        if newState.selectedId == id {
            newState.selectedId = nil
        }

    case .removeArticles(let ids):
        for id in ids {
            newState.byId.removeValue(forKey: id)
            newState.allIds.removeAll { $0 == id }
        }
        if let selectedId = newState.selectedId, ids.contains(selectedId) {
            newState.selectedId = nil
        }

    // MARK: - Article Operations
    case .markAsRead(let id):
        if var article = newState.byId[id] {
            article.markAsRead()
            newState.byId[id] = article
        }

    case .markAllAsRead:
        for id in newState.allIds {
            if var article = newState.byId[id], !article.isRead {
                article.markAsRead()
                newState.byId[id] = article
            }
        }

    case .toggleFavorite(let id):
        if var article = newState.byId[id] {
            article.toggleFavorite()
            newState.byId[id] = article
        }

    case .archiveArticle(let id):
        if var article = newState.byId[id] {
            article.archive()
            newState.byId[id] = article
        }

    case .unarchiveArticle(let id):
        if var article = newState.byId[id] {
            article.isArchived = false
            article.updatedAt = Date()
            newState.byId[id] = article
        }

    // MARK: - NLP Updates
    case .updateNLP(let id, let summary, let keywords, let category, let sentiment, let cluster):
        if var article = newState.byId[id] {
            article.updateNLP(
                summary: summary,
                keywords: keywords,
                category: category,
                sentiment: sentiment,
                cluster: cluster
            )
            newState.byId[id] = article
        }

    case .batchUpdateNLP(let updates):
        for (id, summary, keywords, category, sentiment, cluster) in updates {
            if var article = newState.byId[id] {
                article.updateNLP(
                    summary: summary,
                    keywords: keywords,
                    category: category,
                    sentiment: sentiment,
                    cluster: cluster
                )
                newState.byId[id] = article
            }
        }

    // MARK: - Selection
    case .selectArticle(let id):
        newState.selectedId = id

    // MARK: - Search & Filter
    case .setSearchQuery(let query):
        newState.searchQuery = query

    case .setFilters(let filters):
        newState.filters = filters

    case .setSortOrder(let sortBy):
        newState.sortBy = sortBy

    case .resetFilters:
        newState.filters.reset()
        newState.searchQuery = ""

    // MARK: - Bulk Operations
    case .markMultipleAsRead(let ids):
        for id in ids {
            if var article = newState.byId[id], !article.isRead {
                article.markAsRead()
                newState.byId[id] = article
            }
        }

    case .archiveMultiple(let ids):
        for id in ids {
            if var article = newState.byId[id] {
                article.archive()
                newState.byId[id] = article
            }
        }

    case .deleteOlderThan(let date):
        let idsToRemove = newState.allIds.filter { id in
            if let article = newState.byId[id],
               let publishedAt = article.publishedAt,
               publishedAt < date {
                return true
            }
            return false
        }
        for id in idsToRemove {
            newState.byId.removeValue(forKey: id)
            newState.allIds.removeAll { $0 == id }
        }
    }

    return newState
}
