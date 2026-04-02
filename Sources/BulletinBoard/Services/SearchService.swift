import LINKER

public actor SearchService {

    private var index: [String: Set<String>] = [:]

    private var articles: [String: ArticleMetadata] = [:]

    private struct ArticleMetadata {
        let id: String
        let title: String
        let description: String?
        let content: String?
        let keywords: [String]
    }

    public init() {}

    public func indexArticles(_ articles: [Article]) {
        for article in articles {
            indexArticle(article)
        }
    }

    public func indexArticle(_ article: Article) {
        let metadata = ArticleMetadata(
            id: article.id,
            title: article.title,
            description: article.description,
            content: article.content,
            keywords: article.keywords
        )
        articles[article.id] = metadata

        let titleTerms = extractTerms(from: article.title)
        for term in titleTerms {
            index[term, default: []].insert(article.id)
        }

        if let description = article.description {
            let descTerms = extractTerms(from: description)
            for term in descTerms {
                index[term, default: []].insert(article.id)
            }
        }

        if let content = article.content {
            let contentTerms = extractTerms(from: content)
            for term in contentTerms {
                index[term, default: []].insert(article.id)
            }
        }

        for keyword in article.keywords {
            let keywordTerms = extractTerms(from: keyword)
            for term in keywordTerms {
                index[term, default: []].insert(article.id)
            }
        }
    }

    public func search(query: String, limit: Int = 50) -> [SearchResult] {
        let queryTerms = extractTerms(from: query)

        guard !queryTerms.isEmpty else {
            return []
        }

        var articleScores: [String: (score: Double, fields: Set<String>)] = [:]

        for term in queryTerms {
            guard let matchingArticles = index[term] else { continue }

            for articleId in matchingArticles {
                guard let metadata = articles[articleId] else { continue }

                var score = 0.0
                var matchedFields = articleScores[articleId]?.fields ?? Set<String>()

                if metadata.title.lowercased().contains(term) {
                    score += 3.0
                    matchedFields.insert("title")
                }

                if let description = metadata.description,
                   description.lowercased().contains(term) {
                    score += 2.0
                    matchedFields.insert("description")
                }

                if let content = metadata.content,
                   content.lowercased().contains(term) {
                    score += 1.0
                    matchedFields.insert("content")
                }

                if metadata.keywords.contains(where: { $0.lowercased() == term }) {
                    score += 2.5
                    matchedFields.insert("keywords")
                }

                let currentScore = articleScores[articleId]?.score ?? 0.0
                articleScores[articleId] = (currentScore + score, matchedFields)
            }
        }

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

    public func removeArticle(_ articleId: String) {
        articles.removeValue(forKey: articleId)

        for (term, var articleIds) in index {
            articleIds.remove(articleId)
            if articleIds.isEmpty {
                index.removeValue(forKey: term)
            } else {
                index[term] = articleIds
            }
        }
    }

    public func clearIndex() {
        index.removeAll()
        articles.removeAll()
    }

    public func indexedArticleCount() -> Int {
        articles.count
    }

    public func termCount() -> Int {
        index.count
    }

    private func extractTerms(from text: String) -> [String] {
        TextProcessor.extractTerms(from: text)
    }
}

