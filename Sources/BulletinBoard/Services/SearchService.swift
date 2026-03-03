import Foundation

/// Service for full-text search of articles using an inverted index.
///
/// Provides fast search capabilities with ranking and relevance scoring.
/// Uses an inverted index data structure for efficient lookups.
public actor SearchService {

    // MARK: - Types

    /// Search result with relevance score
    public struct SearchResult: Equatable, Sendable {
        public let articleId: String
        public let score: Double
        public let matchedFields: Set<String>

        public init(articleId: String, score: Double, matchedFields: Set<String>) {
            self.articleId = articleId
            self.score = score
            self.matchedFields = matchedFields
        }
    }

    // MARK: - Properties

    /// Inverted index: term -> [articleId]
    private var index: [String: Set<String>] = [:]

    /// Article metadata for scoring
    private var articles: [String: ArticleMetadata] = [:]

    private struct ArticleMetadata {
        let id: String
        let title: String
        let description: String?
        let content: String?
        let keywords: [String]
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Indexes an array of articles for searching.
    /// - Parameter articles: Articles to index
    public func indexArticles(_ articles: [Article]) {
        for article in articles {
            indexArticle(article)
        }
    }

    /// Indexes a single article.
    /// - Parameter article: Article to index
    public func indexArticle(_ article: Article) {
        // Store metadata
        let metadata = ArticleMetadata(
            id: article.id,
            title: article.title,
            description: article.description,
            content: article.content,
            keywords: article.keywords
        )
        articles[article.id] = metadata

        // Extract and index terms from title (highest weight)
        let titleTerms = extractTerms(from: article.title)
        for term in titleTerms {
            index[term, default: []].insert(article.id)
        }

        // Index description
        if let description = article.description {
            let descTerms = extractTerms(from: description)
            for term in descTerms {
                index[term, default: []].insert(article.id)
            }
        }

        // Index content
        if let content = article.content {
            let contentTerms = extractTerms(from: content)
            for term in contentTerms {
                index[term, default: []].insert(article.id)
            }
        }

        // Index keywords
        for keyword in article.keywords {
            let keywordTerms = extractTerms(from: keyword)
            for term in keywordTerms {
                index[term, default: []].insert(article.id)
            }
        }
    }

    /// Searches for articles matching the query.
    /// - Parameters:
    ///   - query: Search query string
    ///   - limit: Maximum number of results (default: 50)
    /// - Returns: Array of search results sorted by relevance score
    public func search(query: String, limit: Int = 50) -> [SearchResult] {
        let queryTerms = extractTerms(from: query)

        guard !queryTerms.isEmpty else {
            return []
        }

        // Find articles matching any query term
        var articleScores: [String: (score: Double, fields: Set<String>)] = [:]

        for term in queryTerms {
            guard let matchingArticles = index[term] else { continue }

            for articleId in matchingArticles {
                guard let metadata = articles[articleId] else { continue }

                // Calculate score based on where the term appears
                var score = 0.0
                var matchedFields = articleScores[articleId]?.fields ?? Set<String>()

                // Title match: highest weight
                if metadata.title.lowercased().contains(term) {
                    score += 3.0
                    matchedFields.insert("title")
                }

                // Description match: medium weight
                if let description = metadata.description,
                   description.lowercased().contains(term) {
                    score += 2.0
                    matchedFields.insert("description")
                }

                // Content match: lower weight
                if let content = metadata.content,
                   content.lowercased().contains(term) {
                    score += 1.0
                    matchedFields.insert("content")
                }

                // Keyword exact match: high weight
                if metadata.keywords.contains(where: { $0.lowercased() == term }) {
                    score += 2.5
                    matchedFields.insert("keywords")
                }

                // Add to total score
                let currentScore = articleScores[articleId]?.score ?? 0.0
                articleScores[articleId] = (currentScore + score, matchedFields)
            }
        }

        // Convert to SearchResult and sort by score
        let results = articleScores.map { (articleId, data) in
            SearchResult(
                articleId: articleId,
                score: data.score,
                matchedFields: data.fields
            )
        }
        .sorted { $0.score > $1.score }
        .prefix(limit)

        return Array(results)
    }

    /// Removes an article from the index.
    /// - Parameter articleId: Article ID to remove
    public func removeArticle(_ articleId: String) {
        // Remove from metadata
        articles.removeValue(forKey: articleId)

        // Remove from index
        for (term, var articleIds) in index {
            articleIds.remove(articleId)
            if articleIds.isEmpty {
                index.removeValue(forKey: term)
            } else {
                index[term] = articleIds
            }
        }
    }

    /// Clears the entire index.
    public func clearIndex() {
        index.removeAll()
        articles.removeAll()
    }

    /// Returns the number of indexed articles.
    public func indexedArticleCount() -> Int {
        articles.count
    }

    /// Returns the number of unique terms in the index.
    public func termCount() -> Int {
        index.count
    }

    // MARK: - Private Methods

    /// Extracts searchable terms from text.
    /// Tokenizes, lowercases, and filters out stop words.
    private func extractTerms(from text: String) -> [String] {
        let stopWords = Set([
            "a", "an", "and", "are", "as", "at", "be", "by", "for",
            "from", "has", "he", "in", "is", "it", "its", "of", "on",
            "that", "the", "to", "was", "will", "with"
        ])

        return text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && $0.count > 2 && !stopWords.contains($0) }
    }
}
