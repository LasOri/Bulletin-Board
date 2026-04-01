import XCTest
@testable import BulletinBoard
import LINKER

final class ArticleCardGPUTests: XCTestCase {

    var testArticle: Article!

    override func setUp() {
        super.setUp()
        GPUComponentConfig.reset()

        testArticle = Article(
            id: "test-1",
            title: "Test Article",
            url: "https://example.com/article",
            publishedAt: currentTimestamp(),
            feedId: "feed-1"
        )
    }

    private func makeProps(
        article: Article? = nil,
        onToggleFavorite: @escaping (String) -> Void = { _ in },
        onMarkAsRead: @escaping (String) -> Void = { _ in },
        onClick: @escaping (String) -> Void = { _ in }
    ) -> ArticleCard.Props {
        ArticleCard.Props(
            article: article ?? testArticle,
            onToggleFavorite: onToggleFavorite,
            onMarkAsRead: onMarkAsRead,
            onClick: onClick
        )
    }

    private func enableGPU() {
        GPUComponentConfig.enabled = true
    }

    func testRenderGPUReturnsNodes() {
        enableGPU()
        let props = makeProps()
        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "GPU rendering should return nodes")
    }

    func testRenderGPUFallbackWhenDisabled() {
        GPUComponentConfig.enabled = false
        let props = makeProps()
        let gpuNodes = ArticleCard.renderGPU(props: props)
        let standardNodes = ArticleCard.render(props: props)

        XCTAssertFalse(gpuNodes.isEmpty)
        XCTAssertFalse(standardNodes.isEmpty)
    }

    func testComponentOverrideDisablesGPU() {
        enableGPU()
        GPUComponentConfig.componentOverrides["ArticleCard"] = false
        let props = makeProps()
        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Should still render with fallback")
    }

    func testCustomShadowStyle() {
        enableGPU()
        GPUComponentConfig.shadowStyles["ArticleCard"] = (elevation: 5.0, intensity: 0.6)
        let props = makeProps()
        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Custom shadow style should render")
    }

    func testPropsPassedThrough() {
        enableGPU()
        var favoriteToggled = false
        var readMarked = false
        var clicked = false

        let props = makeProps(
            onToggleFavorite: { _ in favoriteToggled = true },
            onMarkAsRead: { _ in readMarked = true },
            onClick: { _ in clicked = true }
        )

        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty)

        props.onToggleFavorite("test")
        props.onMarkAsRead("test")
        props.onClick("test")

        XCTAssertTrue(favoriteToggled, "onToggleFavorite should work")
        XCTAssertTrue(readMarked, "onMarkAsRead should work")
        XCTAssertTrue(clicked, "onClick should work")
    }

    func testLowPerformanceModeFallback() {
        enableGPU()
        GPUComponentConfig.performanceMode = .low
        let props = makeProps()
        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Low performance should fall back to standard render")
    }

    func testHighPerformanceModeUsesGPU() {
        GPUComponentConfig.configureForHighPerformance()
        let props = makeProps()
        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "High performance should use GPU")
    }

    func testRenderGPUWithReadArticle() {
        enableGPU()
        var readArticle = testArticle!
        readArticle.isRead = true
        let props = makeProps(article: readArticle)
        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Should render read article with GPU")
    }

    func testRenderGPUWithFavoriteArticle() {
        enableGPU()
        var favoriteArticle = testArticle!
        favoriteArticle.isFavorite = true
        let props = makeProps(article: favoriteArticle)
        let nodes = ArticleCard.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Should render favorite article with GPU")
    }
}
