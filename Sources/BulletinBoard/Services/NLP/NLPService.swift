import Foundation

/// Orchestrates all NLP processing for articles.
///
/// Coordinates keyword extraction, categorization, entity extraction,
/// redundancy detection, and similarity search across the article corpus.
public actor NLPService {

    private let tfidfEngine = TFIDFEngine()
    private let categorizer = ArticleCategorizer()
    private let redundancyDetector = RedundancyDetector()

    /// Results from NLP processing of a single article.
    public struct NLPResult: Sendable {
        public let articleId: String
        public let keywords: [String]
        public let category: ArticleCategory
        public let entities: [EntityExtractor.Entity]
        public let summary: String?
    }

    public init() {}

    /// Process a single article.
    /// - Parameter article: Article to process
    /// - Returns: NLP results including keywords, category, and entities
    public func processArticle(_ article: Article) async -> NLPResult {
        let text = article.textForNLP

        // Extract keywords using RAKE
        let scoredKeywords = KeywordExtractor.extract(from: text, maxKeywords: 10)
        let keywords = scoredKeywords.map { $0.phrase }

        // Classify category
        let category = await categorizer.classify(text: text, using: tfidfEngine)

        // Extract entities
        let entities = EntityExtractor.extract(from: text)

        // Generate extractive summary (first 2 sentences of description or content)
        let summary = generateSummary(from: article)

        return NLPResult(
            articleId: article.id,
            keywords: keywords,
            category: category,
            entities: entities,
            summary: summary
        )
    }

    /// Process a batch of articles.
    /// - Parameter articles: Articles to process
    /// - Returns: Array of NLP results
    public func processArticles(_ articles: [Article]) async -> [NLPResult] {
        var results: [NLPResult] = []
        for article in articles {
            let result = await processArticle(article)
            results.append(result)
        }
        return results
    }

    /// Find articles similar to a given article.
    /// - Parameters:
    ///   - articleId: Reference article ID
    ///   - limit: Maximum results (default: 5)
    /// - Returns: Array of (id, similarity) tuples
    public func findSimilar(to articleId: String, limit: Int = 5) async -> [(id: String, similarity: Double)] {
        await tfidfEngine.findSimilar(to: articleId, limit: limit)
    }

    /// Find duplicate articles.
    /// - Parameter articleIds: Article IDs to check
    /// - Returns: Array of duplicate groups
    public func findDuplicates(among articleIds: [String]) async -> [RedundancyDetector.DuplicateGroup] {
        await redundancyDetector.findDuplicates(using: tfidfEngine, articleIds: articleIds)
    }

    /// Build/rebuild the TF-IDF corpus from articles.
    /// - Parameter articles: Articles to index
    public func buildCorpus(from articles: [Article]) async {
        await tfidfEngine.clear()
        let documents = articles.map { (id: $0.id, text: $0.textForNLP) }
        await tfidfEngine.indexDocuments(documents)
        print("📊 NLP corpus built: \(articles.count) documents indexed")
    }

    // MARK: - Private

    private func generateSummary(from article: Article) -> String? {
        let source = article.description ?? article.content
        guard let text = source, !text.isEmpty else { return nil }

        let cleaned = TextProcessor.stripHTML(text)
        let sentences = TextProcessor.sentences(from: cleaned)

        guard !sentences.isEmpty else { return nil }

        // Take first 2 sentences as extractive summary
        let summarySentences = sentences.prefix(2)
        let summary = summarySentences.joined(separator: " ")

        // Limit to ~300 characters
        if summary.count > 300 {
            let truncated = String(summary.prefix(297))
            // Try to break at a word boundary
            if let lastSpace = truncated.lastIndex(of: " ") {
                return String(truncated[truncated.startIndex..<lastSpace]) + "..."
            }
            return truncated + "..."
        }

        return summary
    }
}
