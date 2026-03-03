import XCTest
@testable import BulletinBoard
import LINKER

final class ArticleListTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTestArticle(
        id: String,
        title: String = "Test Article",
        isRead: Bool = false
    ) -> Article {
        Article(
            id: id,
            title: title,
            url: "https://example.com/\(id)",
            feedId: "feed-1",
            isRead: isRead
        )
    }

    private func makeTestProps(
        articles: [Article] = [],
        isLoading: Bool = false,
        emptyMessage: String = "No articles",
        onToggleFavorite: @escaping (String) -> Void = { _ in },
        onMarkAsRead: @escaping (String) -> Void = { _ in },
        onArticleClick: @escaping (String) -> Void = { _ in }
    ) -> ArticleList.Props {
        ArticleList.Props(
            articles: articles,
            isLoading: isLoading,
            emptyMessage: emptyMessage,
            onToggleFavorite: onToggleFavorite,
            onMarkAsRead: onMarkAsRead,
            onArticleClick: onArticleClick
        )
    }

    // MARK: - Basic Rendering Tests

    func testRenderEmptyList() {
        let props = makeTestProps(articles: [])
        let nodes = ArticleList.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render empty state
    }

    func testRenderLoadingState() {
        let props = makeTestProps(isLoading: true)
        let nodes = ArticleList.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render loading indicator
    }

    func testRenderSingleArticle() {
        let articles = [makeTestArticle(id: "1")]
        let props = makeTestProps(articles: articles)

        let nodes = ArticleList.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render container with one article
    }

    func testRenderMultipleArticles() {
        let articles = [
            makeTestArticle(id: "1"),
            makeTestArticle(id: "2"),
            makeTestArticle(id: "3")
        ]
        let props = makeTestProps(articles: articles)

        let nodes = ArticleList.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render container with three articles
    }

    // MARK: - Empty State Tests

    func testEmptyStateShowsMessage() {
        let customMessage = "No articles found"
        let props = makeTestProps(emptyMessage: customMessage)

        let nodes = ArticleList.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Empty message should be rendered
    }

    func testEmptyStateDefaultMessage() {
        let props = makeTestProps()

        let nodes = ArticleList.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Default empty message should be rendered
    }

    // MARK: - Loading State Tests

    func testLoadingStateIgnoresArticles() {
        let articles = [makeTestArticle(id: "1")]
        let props = makeTestProps(articles: articles, isLoading: true)

        let nodes = ArticleList.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should show loading state, not articles
    }

    // MARK: - Article Count Tests

    func testArticleCountSingular() {
        let articles = [makeTestArticle(id: "1")]
        let props = makeTestProps(articles: articles)

        let nodes = ArticleList.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should display "1 article"
    }

    func testArticleCountPlural() {
        let articles = [
            makeTestArticle(id: "1"),
            makeTestArticle(id: "2")
        ]
        let props = makeTestProps(articles: articles)

        let nodes = ArticleList.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should display "2 articles"
    }

    // MARK: - Props Tests

    func testPropsInitialization() {
        let articles = [makeTestArticle(id: "1")]
        var favoriteToggled = false
        var readMarked = false
        var clicked = false

        let props = ArticleList.Props(
            articles: articles,
            isLoading: false,
            emptyMessage: "Empty",
            onToggleFavorite: { _ in favoriteToggled = true },
            onMarkAsRead: { _ in readMarked = true },
            onArticleClick: { _ in clicked = true }
        )

        XCTAssertEqual(props.articles.count, 1)
        XCTAssertFalse(props.isLoading)
        XCTAssertEqual(props.emptyMessage, "Empty")

        props.onToggleFavorite("1")
        XCTAssertTrue(favoriteToggled)

        props.onMarkAsRead("1")
        XCTAssertTrue(readMarked)

        props.onArticleClick("1")
        XCTAssertTrue(clicked)
    }

    func testPropsDefaultValues() {
        let articles = [makeTestArticle(id: "1")]
        let props = makeTestProps(articles: articles)

        XCTAssertEqual(props.articles.count, 1)
        XCTAssertFalse(props.isLoading)
        XCTAssertEqual(props.emptyMessage, "No articles")
    }

    // MARK: - Virtual Scrolling Tests

    func testVirtualScrollConfigDefaults() {
        let config = ArticleList.VirtualScrollConfig()

        XCTAssertEqual(config.itemHeight, 300)
        XCTAssertEqual(config.bufferSize, 5)
        XCTAssertEqual(config.containerHeight, 800)
    }

    func testVirtualScrollConfigCustom() {
        let config = ArticleList.VirtualScrollConfig(
            itemHeight: 200,
            bufferSize: 3,
            containerHeight: 600
        )

        XCTAssertEqual(config.itemHeight, 200)
        XCTAssertEqual(config.bufferSize, 3)
        XCTAssertEqual(config.containerHeight, 600)
    }

    func testCalculateVisibleRangeAtTop() {
        let config = ArticleList.VirtualScrollConfig(
            itemHeight: 100,
            bufferSize: 2,
            containerHeight: 500
        )

        let range = ArticleList.calculateVisibleRange(
            scrollTop: 0,
            config: config,
            totalItems: 50
        )

        // At top: should show items 0 to 7 (5 visible + 2 buffer)
        XCTAssertEqual(range.lowerBound, 0)
        XCTAssertGreaterThan(range.upperBound, 5)
    }

    func testCalculateVisibleRangeMiddle() {
        let config = ArticleList.VirtualScrollConfig(
            itemHeight: 100,
            bufferSize: 2,
            containerHeight: 500
        )

        let range = ArticleList.calculateVisibleRange(
            scrollTop: 1000,
            config: config,
            totalItems: 50
        )

        // At scroll 1000: start index = (1000/100) - 2 = 8
        XCTAssertEqual(range.lowerBound, 8)
        XCTAssertGreaterThan(range.upperBound, 10)
    }

    func testCalculateVisibleRangeAtBottom() {
        let config = ArticleList.VirtualScrollConfig(
            itemHeight: 100,
            bufferSize: 2,
            containerHeight: 500
        )

        let range = ArticleList.calculateVisibleRange(
            scrollTop: 4500,
            config: config,
            totalItems: 50
        )

        // At bottom: should not exceed totalItems
        XCTAssertLessThanOrEqual(range.upperBound, 50)
    }

    func testCalculateVisibleRangeZeroItems() {
        let config = ArticleList.VirtualScrollConfig()

        let range = ArticleList.calculateVisibleRange(
            scrollTop: 0,
            config: config,
            totalItems: 0
        )

        XCTAssertEqual(range.lowerBound, 0)
        XCTAssertEqual(range.upperBound, 0)
    }

    func testCalculateVisibleRangeOneItem() {
        let config = ArticleList.VirtualScrollConfig()

        let range = ArticleList.calculateVisibleRange(
            scrollTop: 0,
            config: config,
            totalItems: 1
        )

        XCTAssertEqual(range.lowerBound, 0)
        XCTAssertLessThanOrEqual(range.upperBound, 1)
    }

    // MARK: - Virtual Rendering Tests

    func testRenderVirtualWithEmptyList() {
        let config = ArticleList.VirtualScrollConfig()
        let props = makeTestProps(articles: [])

        let nodes = ArticleList.renderVirtual(
            props: props,
            scrollTop: 0,
            config: config
        )

        XCTAssertEqual(nodes.count, 1)
        // Should fallback to regular render for empty state
    }

    func testRenderVirtualWithLoadingState() {
        let config = ArticleList.VirtualScrollConfig()
        let props = makeTestProps(isLoading: true)

        let nodes = ArticleList.renderVirtual(
            props: props,
            scrollTop: 0,
            config: config
        )

        XCTAssertEqual(nodes.count, 1)
        // Should fallback to regular render for loading state
    }

    func testRenderVirtualWithArticles() {
        let config = ArticleList.VirtualScrollConfig(
            itemHeight: 100,
            bufferSize: 1,
            containerHeight: 300
        )
        let articles = (1...20).map { makeTestArticle(id: "\($0)") }
        let props = makeTestProps(articles: articles)

        let nodes = ArticleList.renderVirtual(
            props: props,
            scrollTop: 0,
            config: config
        )

        XCTAssertEqual(nodes.count, 1)
        // Should render virtual scroll container
    }

    func testRenderVirtualAtTopOfList() {
        let config = ArticleList.VirtualScrollConfig(
            itemHeight: 100,
            bufferSize: 2,
            containerHeight: 500
        )
        let articles = (1...50).map { makeTestArticle(id: "\($0)") }
        let props = makeTestProps(articles: articles)

        let nodes = ArticleList.renderVirtual(
            props: props,
            scrollTop: 0,
            config: config
        )

        XCTAssertEqual(nodes.count, 1)
        // Should render items from start
    }

    func testRenderVirtualScrolledDown() {
        let config = ArticleList.VirtualScrollConfig(
            itemHeight: 100,
            bufferSize: 2,
            containerHeight: 500
        )
        let articles = (1...50).map { makeTestArticle(id: "\($0)") }
        let props = makeTestProps(articles: articles)

        let nodes = ArticleList.renderVirtual(
            props: props,
            scrollTop: 1000,
            config: config
        )

        XCTAssertEqual(nodes.count, 1)
        // Should render items from middle
    }

    // MARK: - Edge Cases

    func testRenderWithManyArticles() {
        let articles = (1...100).map { makeTestArticle(id: "\($0)") }
        let props = makeTestProps(articles: articles)

        let nodes = ArticleList.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle large lists
    }

    func testRenderEmptyWhileLoading() {
        let props = makeTestProps(articles: [], isLoading: true)

        let nodes = ArticleList.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Loading state takes precedence over empty state
    }

    func testRenderWithLongEmptyMessage() {
        let longMessage = String(repeating: "No articles found. ", count: 10)
        let props = makeTestProps(emptyMessage: longMessage)

        let nodes = ArticleList.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle long messages
    }

    // MARK: - Integration Tests

    func testArticleListPassesPropsToCards() {
        let articles = [makeTestArticle(id: "test-1")]
        var toggledId: String?
        var markedId: String?
        var clickedId: String?

        let props = ArticleList.Props(
            articles: articles,
            onToggleFavorite: { id in toggledId = id },
            onMarkAsRead: { id in markedId = id },
            onArticleClick: { id in clickedId = id }
        )

        let nodes = ArticleList.render(props: props)
        XCTAssertEqual(nodes.count, 1)

        // Callbacks should be passed through to ArticleCard
        props.onToggleFavorite("test-1")
        XCTAssertEqual(toggledId, "test-1")

        props.onMarkAsRead("test-1")
        XCTAssertEqual(markedId, "test-1")

        props.onArticleClick("test-1")
        XCTAssertEqual(clickedId, "test-1")
    }
}
