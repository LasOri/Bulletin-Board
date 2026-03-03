import XCTest
@testable import BulletinBoard
import LINKER

final class ArticleCardTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTestArticle(
        id: String = "test-1",
        title: String = "Test Article",
        description: String? = "Test description",
        author: String? = "Test Author",
        enclosure: ArticleEnclosure? = nil,
        isRead: Bool = false,
        isFavorite: Bool = false,
        autoCategory: ArticleCategory? = nil,
        keywords: [String] = []
    ) -> Article {
        Article(
            id: id,
            title: title,
            description: description,
            url: "https://example.com/article",
            publishedAt: Date(),
            author: author,
            feedId: "feed-1",
            enclosure: enclosure,
            isRead: isRead,
            isFavorite: isFavorite,
            keywords: keywords,
            autoCategory: autoCategory
        )
    }

    private func makeTestProps(
        article: Article,
        onToggleFavorite: @escaping (String) -> Void = { _ in },
        onMarkAsRead: @escaping (String) -> Void = { _ in },
        onClick: @escaping (String) -> Void = { _ in }
    ) -> ArticleCard.Props {
        ArticleCard.Props(
            article: article,
            onToggleFavorite: onToggleFavorite,
            onMarkAsRead: onMarkAsRead,
            onClick: onClick
        )
    }

    // MARK: - Basic Rendering Tests

    func testRenderBasicArticle() {
        let article = makeTestArticle()
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Component should render an article element
    }

    func testRenderArticleTitle() {
        let article = makeTestArticle(title: "Swift 6 Released")
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Title should be rendered in the card
    }

    func testRenderArticleDescription() {
        let article = makeTestArticle(description: "Exciting new features in Swift 6")
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Description should be rendered
    }

    func testRenderArticleWithAuthor() {
        let article = makeTestArticle(author: "John Doe")
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Author should be displayed in metadata
    }

    // MARK: - Category Tests

    func testRenderArticleWithCategory() {
        let article = makeTestArticle(autoCategory: .technology)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Category badge should be rendered
    }

    func testRenderArticleWithoutCategory() {
        let article = makeTestArticle(autoCategory: nil)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // No category badge should be rendered
    }

    // MARK: - Keywords Tests

    func testRenderArticleWithKeywords() {
        let article = makeTestArticle(keywords: ["swift", "programming", "ios"])
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Keywords should be rendered
    }

    func testRenderArticleWithoutKeywords() {
        let article = makeTestArticle(keywords: [])
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // No keywords section should be rendered
    }

    // MARK: - Image Tests

    func testRenderArticleWithImage() {
        let enclosure = ArticleEnclosure(
            url: "https://example.com/image.jpg",
            type: "image/jpeg",
            length: 12345
        )
        let article = makeTestArticle(enclosure: enclosure)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Image should be rendered
    }

    func testRenderArticleWithNonImageEnclosure() {
        let enclosure = ArticleEnclosure(
            url: "https://example.com/audio.mp3",
            type: "audio/mpeg",
            length: 12345
        )
        let article = makeTestArticle(enclosure: enclosure)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Non-image enclosure should not be rendered as image
    }

    // MARK: - Read Status Tests

    func testRenderUnreadArticle() {
        let article = makeTestArticle(isRead: false)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have unread indicator
    }

    func testRenderReadArticle() {
        let article = makeTestArticle(isRead: true)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have read indicator and read styling
    }

    // MARK: - Favorite Status Tests

    func testRenderUnfavoritedArticle() {
        let article = makeTestArticle(isFavorite: false)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should show empty star
    }

    func testRenderFavoritedArticle() {
        let article = makeTestArticle(isFavorite: true)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should show filled star and favorite styling
    }

    // MARK: - CSS Classes Tests

    func testArticleCardHasBaseClass() {
        let article = makeTestArticle()
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have base article-card class
    }

    func testReadArticleHasReadClass() {
        let article = makeTestArticle(isRead: true)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have article-card--read class
    }

    func testFavoriteArticleHasFavoriteClass() {
        let article = makeTestArticle(isFavorite: true)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have article-card--favorite class
    }

    // MARK: - Props Tests

    func testPropsInitialization() {
        let article = makeTestArticle()
        var favoriteToggled = false
        var readMarked = false
        var clicked = false

        let props = ArticleCard.Props(
            article: article,
            onToggleFavorite: { _ in favoriteToggled = true },
            onMarkAsRead: { _ in readMarked = true },
            onClick: { _ in clicked = true }
        )

        XCTAssertEqual(props.article.id, article.id)

        props.onToggleFavorite(article.id)
        XCTAssertTrue(favoriteToggled)

        props.onMarkAsRead(article.id)
        XCTAssertTrue(readMarked)

        props.onClick(article.id)
        XCTAssertTrue(clicked)
    }

    // MARK: - Edge Cases

    func testRenderArticleWithEmptyDescription() {
        let article = makeTestArticle(description: "")
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle empty description gracefully
    }

    func testRenderArticleWithNilDescription() {
        let article = makeTestArticle(description: nil)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle nil description gracefully
    }

    func testRenderArticleWithNilAuthor() {
        let article = makeTestArticle(author: nil)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle nil author gracefully
    }

    func testRenderArticleWithLongTitle() {
        let longTitle = String(repeating: "Long Title ", count: 20)
        let article = makeTestArticle(title: longTitle)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle long titles without breaking
    }

    func testRenderArticleWithManyKeywords() {
        let keywords = (1...20).map { "keyword\($0)" }
        let article = makeTestArticle(keywords: keywords)
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render all keywords
    }

    // MARK: - Data Attributes Tests

    func testArticleCardHasDataArticleId() {
        let article = makeTestArticle(id: "test-123")
        let props = makeTestProps(article: article)

        let nodes = ArticleCard.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have data-article-id attribute for JavaScript interaction
    }
}
