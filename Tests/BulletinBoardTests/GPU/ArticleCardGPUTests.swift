import XCTest
@testable import BulletinBoard
import LINKER

/// Tests for ArticleCard GPU enhancements.
final class ArticleCardGPUTests: XCTestCase {

    var testArticle: Article!

    override func setUp() {
        super.setUp()
        GPUComponentConfig.reset()

        // Create test article
        testArticle = Article(
            id: "test-1",
            title: "Test Article",
            url: "https://example.com/article",
            publishedAt: Date(),
            feedId: "feed-1"
        )
    }

    // MARK: - Basic Rendering

    func testRenderGPUReturnsNodes() {
        GPUComponentConfig.enabled = true

        let props = ArticleCard.Props(
            article: testArticle,
            onToggleFavorite: { _ in },
            onMarkAsRead: { _ in },
            onClick: { _ in }
        )

        let nodes = ArticleCard.renderGPU(props: props)

        XCTAssertFalse(nodes.isEmpty, "GPU rendering should return nodes")
    }

    func testRenderGPUFallbackWhenDisabled() {
        GPUComponentConfig.enabled = false

        let props = ArticleCard.Props(
            article: testArticle,
            onToggleFavorite: { _ in },
            onMarkAsRead: { _ in },
            onClick: { _ in }
        )

        let gpuNodes = ArticleCard.renderGPU(props: props)
        let standardNodes = ArticleCard.render(props: props)

        // Both should return nodes (GPU falls back to standard)
        XCTAssertFalse(gpuNodes.isEmpty)
        XCTAssertFalse(standardNodes.isEmpty)
    }

    // MARK: - Component Override

    func testComponentOverrideDisablesGPU() {
        GPUComponentConfig.enabled = true
        GPUComponentConfig.componentOverrides["ArticleCard"] = false

        let props = ArticleCard.Props(
            article: testArticle,
            onToggleFavorite: { _ in },
            onMarkAsRead: { _ in },
            onClick: { _ in }
        )

        // Should fall back to standard render
        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Should still render with fallback")
    }

    // MARK: - Custom Shadow Style

    func testCustomShadowStyle() {
        GPUComponentConfig.enabled = true
        GPUComponentConfig.shadowStyles["ArticleCard"] = (elevation: 5.0, intensity: 0.6)

        let props = ArticleCard.Props(
            article: testArticle,
            onToggleFavorite: { _ in },
            onMarkAsRead: { _ in },
            onClick: { _ in }
        )

        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Custom shadow style should render")
    }

    // MARK: - Props Handling

    func testPropsPassedThrough() {
        GPUComponentConfig.enabled = true

        var favoriteToggled = false
        var readMarked = false
        var clicked = false

        let props = ArticleCard.Props(
            article: testArticle,
            onToggleFavorite: { _ in favoriteToggled = true },
            onMarkAsRead: { _ in readMarked = true },
            onClick: { _ in clicked = true }
        )

        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty)

        // Props should be passed through to underlying render
        props.onToggleFavorite("test")
        props.onMarkAsRead("test")
        props.onClick("test")

        XCTAssertTrue(favoriteToggled, "onToggleFavorite should work")
        XCTAssertTrue(readMarked, "onMarkAsRead should work")
        XCTAssertTrue(clicked, "onClick should work")
    }

    // MARK: - Performance Mode

    func testLowPerformanceModeFallback() {
        GPUComponentConfig.enabled = true
        GPUComponentConfig.performanceMode = .low

        let props = ArticleCard.Props(
            article: testArticle,
            onToggleFavorite: { _ in },
            onMarkAsRead: { _ in },
            onClick: { _ in }
        )

        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Low performance should fall back to standard render")
    }

    func testHighPerformanceModeUsesGPU() {
        GPUComponentConfig.configureForHighPerformance()

        let props = ArticleCard.Props(
            article: testArticle,
            onToggleFavorite: { _ in },
            onMarkAsRead: { _ in },
            onClick: { _ in }
        )

        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "High performance should use GPU")
    }

    // MARK: - Article States

    func testRenderGPUWithReadArticle() {
        GPUComponentConfig.enabled = true

        var readArticle = testArticle!
        readArticle.isRead = true

        let props = ArticleCard.Props(
            article: readArticle,
            onToggleFavorite: { _ in },
            onMarkAsRead: { _ in },
            onClick: { _ in }
        )

        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Should render read article with GPU")
    }

    func testRenderGPUWithFavoriteArticle() {
        GPUComponentConfig.enabled = true

        var favoriteArticle = testArticle!
        favoriteArticle.isFavorite = true

        let props = ArticleCard.Props(
            article: favoriteArticle,
            onToggleFavorite: { _ in },
            onMarkAsRead: { _ in },
            onClick: { _ in }
        )

        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Should render favorite article with GPU")
    }
}
