import Foundation
import LINKER

public actor NLPService {

    private let tfidfEngine = TFIDFEngine()
    private let categorizer = ArticleCategorizer()
    private let redundancyDetector = RedundancyDetector()

    public struct NLPResult: Sendable {
        public let articleId: String
        public let keywords: [String]
        public let category: ArticleCategory
        public let entities: [EntityExtractor.Entity]
        public let summary: String?
        public let sentimentScore: Double
    }

    public init() {}

    public func processArticle(_ article: Article) async -> NLPResult {
        let text = article.textForNLP

        let scoredKeywords = KeywordExtractor.extract(from: text, maxKeywords: 10)
        let keywords = scoredKeywords.map { $0.phrase }

        let category = await categorizer.classify(text: text, using: tfidfEngine)

        let entities = EntityExtractor.extract(from: text)

        let summary = generateSummary(from: article)

        let sentimentScore = SentimentAnalyzer.analyze(text: text)

        return NLPResult(
            articleId: article.id,
            keywords: keywords,
            category: category,
            entities: entities,
            summary: summary,
            sentimentScore: sentimentScore
        )
    }

    public func processArticles(_ articles: [Article]) async -> [NLPResult] {
        var results: [NLPResult] = []
        for article in articles {
            let result = await processArticle(article)
            results.append(result)
        }
        return results
    }

    public func findSimilar(to articleId: String, limit: Int = 5) async -> [(id: String, similarity: Double)] {
        await tfidfEngine.findSimilar(to: articleId, limit: limit)
    }

    public func findDuplicates(among articleIds: [String]) async -> [RedundancyDetector.DuplicateGroup] {
        await redundancyDetector.findDuplicates(using: tfidfEngine, articleIds: articleIds)
    }

    public func buildCorpus(from articles: [Article]) async {
        await tfidfEngine.clear()
        let documents = articles.map { (id: $0.id, text: $0.textForNLP) }
        await tfidfEngine.indexDocuments(documents)
    }

    public func updateCorpus(with documents: [(id: String, text: String)], batchSize: Int = 3) async -> [String] {
        let alreadyIndexed = await tfidfEngine.indexedDocumentIds
        let newDocs = documents.filter { !alreadyIndexed.contains($0.id) }
        var newIds: [String] = []

        for batchStart in stride(from: 0, to: newDocs.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, newDocs.count)
            for i in batchStart..<batchEnd {
                let doc = newDocs[i]
                await tfidfEngine.indexDocumentIfNew(id: doc.id, text: doc.text)
                newIds.append(doc.id)
            }
            if batchEnd < newDocs.count {
                try? await Task.sleep(nanoseconds: 1_000_000)
            }
        }
        return newIds
    }

    public func clusterArticles(_ articleIds: [String], threshold: Double = 0.15) async -> [String: Int] {
        var pairs: [TextClusterer.SimilarityPair] = []

        for id in articleIds {
            let similar = await tfidfEngine.findSimilar(to: id, limit: 10, threshold: threshold)
            for match in similar {
                pairs.append(TextClusterer.SimilarityPair(
                    id1: id,
                    id2: match.id,
                    similarity: match.similarity
                ))
            }
        }

        return TextClusterer.cluster(similarities: pairs, threshold: threshold)
    }

    public func clusterIncremental(
        newIds: [String],
        existingIds: [String],
        threshold: Double = 0.15
    ) async -> [String: Int] {
        let similarities = await tfidfEngine.pairwiseSimilarities(
            newIds: newIds,
            existingIds: existingIds,
            threshold: threshold,
            maxComparisons: 50
        )

        let pairs = similarities.map {
            TextClusterer.SimilarityPair(id1: $0.id1, id2: $0.id2, similarity: $0.similarity)
        }

        return TextClusterer.cluster(similarities: pairs, threshold: threshold)
    }

    private func generateSummary(from article: Article) -> String? {
        let source = article.description ?? article.content
        guard let text = source, !text.isEmpty else { return nil }

        let truncatedSource = text.count > 1000 ? String(text.prefix(1000)) : text
        let cleaned = TextProcessor.stripHTML(truncatedSource)
        let sentences = TextProcessor.sentences(from: cleaned)

        guard !sentences.isEmpty else { return nil }

        let summarySentences = sentences.prefix(2)
        let summary = summarySentences.joined(separator: " ")

        if summary.count > 300 {
            let truncated = String(summary.prefix(297))
            if let lastSpace = truncated.lastIndex(of: " ") {
                return String(truncated[truncated.startIndex..<lastSpace]) + "..."
            }
            return truncated + "..."
        }

        return summary
    }
}

