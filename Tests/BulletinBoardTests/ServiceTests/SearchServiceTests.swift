import XCTest
@testable import BulletinBoard

final class SearchServiceTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTestSearchService() -> SearchService {
        SearchService()
    }

    private func makeTestArticle(
        id: String,
        title: String,
        description: String? = nil,
        content: String? = nil,
        keywords: [String] = []
    ) -> Article {
        Article(
            id: id,
            title: title,
            description: description,
            content: content,
            url: "https://example.com/\(id)",
            feedId: "feed-1",
            keywords: keywords
        )
    }

    // MARK: - Indexing Tests

    func testIndexSingleArticle() async {
        let service = makeTestSearchService()
        let article = makeTestArticle(
            id: "1",
            title: "Swift Programming Guide"
        )

        await service.indexArticle(article)

        let count = await service.indexedArticleCount()
        XCTAssertEqual(count, 1)
    }

    func testIndexMultipleArticles() async {
        let service = makeTestSearchService()
        let articles = [
            makeTestArticle(id: "1", title: "Swift Programming"),
            makeTestArticle(id: "2", title: "iOS Development"),
            makeTestArticle(id: "3", title: "Web Development")
        ]

        await service.indexArticles(articles)

        let count = await service.indexedArticleCount()
        XCTAssertEqual(count, 3)
    }

    func testTermCountAfterIndexing() async {
        let service = makeTestSearchService()
        let article = makeTestArticle(
            id: "1",
            title: "Swift Programming Guide for Beginners"
        )

        await service.indexArticle(article)

        let termCount = await service.termCount()
        // "swift", "programming", "guide", "beginners" (4 terms, "for" is stop word)
        XCTAssertGreaterThan(termCount, 0)
    }

    // MARK: - Basic Search Tests

    func testSearchByTitle() async {
        let service = makeTestSearchService()
        let articles = [
            makeTestArticle(id: "1", title: "Swift Programming"),
            makeTestArticle(id: "2", title: "JavaScript Basics"),
            makeTestArticle(id: "3", title: "Python Tutorial")
        ]

        await service.indexArticles(articles)
        let results = await service.search(query: "Swift")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].articleId, "1")
        XCTAssertTrue(results[0].matchedFields.contains("title"))
    }

    func testSearchByDescription() async {
        let service = makeTestSearchService()
        let article = makeTestArticle(
            id: "1",
            title: "Article Title",
            description: "This article discusses advanced programming techniques"
        )

        await service.indexArticle(article)
        let results = await service.search(query: "programming")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].articleId, "1")
        XCTAssertTrue(results[0].matchedFields.contains("description"))
    }

    func testSearchByContent() async {
        let service = makeTestSearchService()
        let article = makeTestArticle(
            id: "1",
            title: "Article",
            content: "The content contains information about databases"
        )

        await service.indexArticle(article)
        let results = await service.search(query: "databases")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].articleId, "1")
        XCTAssertTrue(results[0].matchedFields.contains("content"))
    }

    func testSearchByKeywords() async {
        let service = makeTestSearchService()
        let article = makeTestArticle(
            id: "1",
            title: "Article",
            keywords: ["swift", "ios", "mobile"]
        )

        await service.indexArticle(article)
        let results = await service.search(query: "swift")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].articleId, "1")
        XCTAssertTrue(results[0].matchedFields.contains("keywords"))
    }

    // MARK: - Scoring Tests

    func testScoreRankingTitleHigherThanContent() async {
        let service = makeTestSearchService()
        let articles = [
            makeTestArticle(id: "1", title: "Article", content: "Contains swift programming"),
            makeTestArticle(id: "2", title: "Swift Programming Guide")
        ]

        await service.indexArticles(articles)
        let results = await service.search(query: "swift")

        XCTAssertEqual(results.count, 2)
        // Article with "swift" in title should rank higher
        XCTAssertEqual(results[0].articleId, "2")
        XCTAssertGreaterThan(results[0].score, results[1].score)
    }

    func testMultipleMatches() async {
        let service = makeTestSearchService()
        let article = makeTestArticle(
            id: "1",
            title: "Swift Programming",
            description: "Learn Swift programming language",
            keywords: ["swift"]
        )

        await service.indexArticle(article)
        let results = await service.search(query: "swift")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].articleId, "1")
        // Should match in multiple fields
        XCTAssertTrue(results[0].matchedFields.contains("title"))
        XCTAssertTrue(results[0].matchedFields.contains("description"))
        XCTAssertTrue(results[0].matchedFields.contains("keywords"))
        // Score should be higher due to multiple matches
        XCTAssertGreaterThan(results[0].score, 3.0)
    }

    // MARK: - Multi-term Search Tests

    func testMultiTermSearch() async {
        let service = makeTestSearchService()
        let articles = [
            makeTestArticle(id: "1", title: "Swift Programming Guide"),
            makeTestArticle(id: "2", title: "Python Programming Tutorial"),
            makeTestArticle(id: "3", title: "Swift Language Features")
        ]

        await service.indexArticles(articles)
        let results = await service.search(query: "swift programming")

        XCTAssertGreaterThan(results.count, 0)
        // Article 1 should rank highest (matches both terms)
        XCTAssertEqual(results[0].articleId, "1")
    }

    // MARK: - Edge Cases

    func testSearchEmptyQuery() async {
        let service = makeTestSearchService()
        let article = makeTestArticle(id: "1", title: "Test Article")

        await service.indexArticle(article)
        let results = await service.search(query: "")

        XCTAssertEqual(results.count, 0)
    }

    func testSearchNoResults() async {
        let service = makeTestSearchService()
        let article = makeTestArticle(id: "1", title: "Swift Programming")

        await service.indexArticle(article)
        let results = await service.search(query: "javascript")

        XCTAssertEqual(results.count, 0)
    }

    func testSearchWithStopWords() async {
        let service = makeTestSearchService()
        let article = makeTestArticle(id: "1", title: "The Swift Programming Language")

        await service.indexArticle(article)
        // "the" is a stop word and should be ignored
        let results = await service.search(query: "the")

        XCTAssertEqual(results.count, 0)
    }

    func testSearchCaseInsensitive() async {
        let service = makeTestSearchService()
        let article = makeTestArticle(id: "1", title: "Swift Programming")

        await service.indexArticle(article)
        let results1 = await service.search(query: "SWIFT")
        let results2 = await service.search(query: "swift")
        let results3 = await service.search(query: "SwIfT")

        XCTAssertEqual(results1.count, 1)
        XCTAssertEqual(results2.count, 1)
        XCTAssertEqual(results3.count, 1)
        XCTAssertEqual(results1[0].articleId, "1")
        XCTAssertEqual(results2[0].articleId, "1")
        XCTAssertEqual(results3[0].articleId, "1")
    }

    // MARK: - Limit Tests

    func testSearchWithLimit() async {
        let service = makeTestSearchService()
        let articles = (1...10).map { i in
            makeTestArticle(id: "\(i)", title: "Programming Article \(i)")
        }

        await service.indexArticles(articles)
        let results = await service.search(query: "programming", limit: 5)

        XCTAssertEqual(results.count, 5)
    }

    // MARK: - Remove Tests

    func testRemoveArticle() async {
        let service = makeTestSearchService()
        let articles = [
            makeTestArticle(id: "1", title: "Swift Programming"),
            makeTestArticle(id: "2", title: "Python Programming")
        ]

        await service.indexArticles(articles)
        var count = await service.indexedArticleCount()
        XCTAssertEqual(count, 2)

        await service.removeArticle("1")
        count = await service.indexedArticleCount()
        XCTAssertEqual(count, 1)

        let results = await service.search(query: "swift")
        XCTAssertEqual(results.count, 0)

        let pythonResults = await service.search(query: "python")
        XCTAssertEqual(pythonResults.count, 1)
    }

    func testRemoveNonExistentArticle() async {
        let service = makeTestSearchService()
        let article = makeTestArticle(id: "1", title: "Test")

        await service.indexArticle(article)
        await service.removeArticle("nonexistent")

        let count = await service.indexedArticleCount()
        XCTAssertEqual(count, 1)
    }

    // MARK: - Clear Tests

    func testClearIndex() async {
        let service = makeTestSearchService()
        let articles = [
            makeTestArticle(id: "1", title: "Swift"),
            makeTestArticle(id: "2", title: "Python"),
            makeTestArticle(id: "3", title: "JavaScript")
        ]

        await service.indexArticles(articles)
        var count = await service.indexedArticleCount()
        XCTAssertEqual(count, 3)

        await service.clearIndex()
        count = await service.indexedArticleCount()
        XCTAssertEqual(count, 0)

        let termCount = await service.termCount()
        XCTAssertEqual(termCount, 0)

        let results = await service.search(query: "swift")
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - SearchResult Tests

    func testSearchResultEquatable() {
        let result1 = SearchService.SearchResult(
            articleId: "1",
            score: 5.0,
            matchedFields: ["title", "description"]
        )
        let result2 = SearchService.SearchResult(
            articleId: "1",
            score: 5.0,
            matchedFields: ["title", "description"]
        )
        let result3 = SearchService.SearchResult(
            articleId: "2",
            score: 5.0,
            matchedFields: ["title"]
        )

        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }

    // MARK: - Performance Tests

    func testSearchPerformanceWithManyArticles() async {
        let service = makeTestSearchService()
        let articles = (1...100).map { i in
            makeTestArticle(
                id: "\(i)",
                title: "Article \(i) about programming",
                description: "This is article number \(i) discussing various programming topics"
            )
        }

        await service.indexArticles(articles)

        let start = Date()
        let results = await service.search(query: "programming")
        let duration = Date().timeIntervalSince(start)

        XCTAssertGreaterThan(results.count, 0)
        // Should complete in under 100ms
        XCTAssertLessThan(duration, 0.1)
    }
}
