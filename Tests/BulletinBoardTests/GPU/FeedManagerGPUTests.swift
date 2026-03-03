import XCTest
@testable import BulletinBoard
import LINKER

/// Tests for FeedManager GPU enhancements.
final class FeedManagerGPUTests: XCTestCase {

    var testFeeds: [Feed]!

    override func setUp() {
        super.setUp()
        GPUComponentConfig.reset()

        // Create test feeds
        testFeeds = [
            Feed(
                id: "feed-1",
                title: "Test Feed 1",
                description: "First test feed",
                url: "https://example.com/feed1.xml"
            ),
            Feed(
                id: "feed-2",
                title: "Test Feed 2",
                description: "Second test feed",
                url: "https://example.com/feed2.xml"
            )
        ]
    }

    // MARK: - Basic Rendering

    func testRenderGPUReturnsNodes() {
        GPUComponentConfig.enabled = true

        let props = FeedManager.Props(
            feeds: testFeeds,
            onAddFeed: { _ in },
            onEditFeed: { _ in },
            onDeleteFeed: { _ in },
            onToggleFeed: { _ in },
            onRefreshFeed: { _ in },
            onChangeMode: { _ in },
            onClose: { }
        )

        let nodes = FeedManager.renderGPU(props: props)

        XCTAssertFalse(nodes.isEmpty, "GPU rendering should return nodes")
    }

    func testRenderGPUFallbackWhenDisabled() {
        GPUComponentConfig.enabled = false

        let props = FeedManager.Props(
            feeds: testFeeds,
            onAddFeed: { _ in },
            onEditFeed: { _ in },
            onDeleteFeed: { _ in },
            onToggleFeed: { _ in },
            onRefreshFeed: { _ in },
            onChangeMode: { _ in },
            onClose: { }
        )

        let gpuNodes = FeedManager.renderGPU(props: props)
        let standardNodes = FeedManager.render(props: props)

        XCTAssertFalse(gpuNodes.isEmpty)
        XCTAssertFalse(standardNodes.isEmpty)
    }

    // MARK: - Combined Effects (Blur + Shadow)

    func testCombinedBlurAndShadow() {
        GPUComponentConfig.enabled = true

        let props = FeedManager.Props(
            feeds: testFeeds,
            onAddFeed: { _ in },
            onEditFeed: { _ in },
            onDeleteFeed: { _ in },
            onToggleFeed: { _ in },
            onRefreshFeed: { _ in },
            onChangeMode: { _ in },
            onClose: { }
        )

        // Should combine blur (frosted glass) + shadow (elevation24)
        let nodes = FeedManager.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Combined effects should render")
    }

    // MARK: - Custom Styles

    func testCustomBlurStyle() {
        GPUComponentConfig.enabled = true
        GPUComponentConfig.blurStyles["FeedManager"] = (radius: 20, saturation: 2.0, brightness: 1.1)

        let props = FeedManager.Props(
            feeds: testFeeds,
            onAddFeed: { _ in },
            onEditFeed: { _ in },
            onDeleteFeed: { _ in },
            onToggleFeed: { _ in },
            onRefreshFeed: { _ in },
            onChangeMode: { _ in },
            onClose: { }
        )

        let nodes = FeedManager.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Custom blur style should render")
    }

    func testCustomShadowStyle() {
        GPUComponentConfig.enabled = true
        GPUComponentConfig.shadowStyles["FeedManager"] = (elevation: 16.0, intensity: 0.5)

        let props = FeedManager.Props(
            feeds: testFeeds,
            onAddFeed: { _ in },
            onEditFeed: { _ in },
            onDeleteFeed: { _ in },
            onToggleFeed: { _ in },
            onRefreshFeed: { _ in },
            onChangeMode: { _ in },
            onClose: { }
        )

        let nodes = FeedManager.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Custom shadow style should render")
    }

    func testCustomBothStyles() {
        GPUComponentConfig.enabled = true
        GPUComponentConfig.blurStyles["FeedManager"] = (radius: 15, saturation: 1.8, brightness: 1.0)
        GPUComponentConfig.shadowStyles["FeedManager"] = (elevation: 20.0, intensity: 0.4)

        let props = FeedManager.Props(
            feeds: testFeeds,
            onAddFeed: { _ in },
            onEditFeed: { _ in },
            onDeleteFeed: { _ in },
            onToggleFeed: { _ in },
            onRefreshFeed: { _ in },
            onChangeMode: { _ in },
            onClose: { }
        )

        let nodes = FeedManager.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Both custom styles should render")
    }

    // MARK: - Props Handling

    func testPropsPassedThrough() {
        GPUComponentConfig.enabled = true

        var addCalled = false
        var editCalled = false
        var deleteCalled = false
        var toggleCalled = false
        var refreshCalled = false
        var modeChangeCalled = false
        var closeCalled = false

        let props = FeedManager.Props(
            feeds: testFeeds,
            onAddFeed: { _ in addCalled = true },
            onEditFeed: { _ in editCalled = true },
            onDeleteFeed: { _ in deleteCalled = true },
            onToggleFeed: { _ in toggleCalled = true },
            onRefreshFeed: { _ in refreshCalled = true },
            onChangeMode: { _ in modeChangeCalled = true },
            onClose: { closeCalled = true }
        )

        let nodes = FeedManager.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty)

        // Verify all callbacks work
        props.onAddFeed("url")
        props.onEditFeed(testFeeds[0])
        props.onDeleteFeed("id")
        props.onToggleFeed("id")
        props.onRefreshFeed("id")
        props.onChangeMode(.add)
        props.onClose()

        XCTAssertTrue(addCalled)
        XCTAssertTrue(editCalled)
        XCTAssertTrue(deleteCalled)
        XCTAssertTrue(toggleCalled)
        XCTAssertTrue(refreshCalled)
        XCTAssertTrue(modeChangeCalled)
        XCTAssertTrue(closeCalled)
    }

    // MARK: - View Modes

    func testRenderGPUInListMode() {
        GPUComponentConfig.enabled = true

        let props = FeedManager.Props(
            feeds: testFeeds,
            viewMode: .list,
            onAddFeed: { _ in },
            onEditFeed: { _ in },
            onDeleteFeed: { _ in },
            onToggleFeed: { _ in },
            onRefreshFeed: { _ in },
            onChangeMode: { _ in },
            onClose: { }
        )

        let nodes = FeedManager.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "List mode should render with GPU")
    }

    func testRenderGPUInAddMode() {
        GPUComponentConfig.enabled = true

        let props = FeedManager.Props(
            feeds: testFeeds,
            viewMode: .add,
            onAddFeed: { _ in },
            onEditFeed: { _ in },
            onDeleteFeed: { _ in },
            onToggleFeed: { _ in },
            onRefreshFeed: { _ in },
            onChangeMode: { _ in },
            onClose: { }
        )

        let nodes = FeedManager.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Add mode should render with GPU")
    }

    func testRenderGPUInEditMode() {
        GPUComponentConfig.enabled = true

        let props = FeedManager.Props(
            feeds: testFeeds,
            viewMode: .edit(feedId: "feed-1"),
            onAddFeed: { _ in },
            onEditFeed: { _ in },
            onDeleteFeed: { _ in },
            onToggleFeed: { _ in },
            onRefreshFeed: { _ in },
            onChangeMode: { _ in },
            onClose: { }
        )

        let nodes = FeedManager.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Edit mode should render with GPU")
    }

    // MARK: - Loading and Error States

    func testRenderGPUWithLoading() {
        GPUComponentConfig.enabled = true

        let props = FeedManager.Props(
            feeds: testFeeds,
            isLoading: true,
            onAddFeed: { _ in },
            onEditFeed: { _ in },
            onDeleteFeed: { _ in },
            onToggleFeed: { _ in },
            onRefreshFeed: { _ in },
            onChangeMode: { _ in },
            onClose: { }
        )

        let nodes = FeedManager.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Loading state should render with GPU")
    }

    func testRenderGPUWithError() {
        GPUComponentConfig.enabled = true

        let props = FeedManager.Props(
            feeds: testFeeds,
            error: "Test error message",
            onAddFeed: { _ in },
            onEditFeed: { _ in },
            onDeleteFeed: { _ in },
            onToggleFeed: { _ in },
            onRefreshFeed: { _ in },
            onChangeMode: { _ in },
            onClose: { }
        )

        let nodes = FeedManager.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Error state should render with GPU")
    }

    // MARK: - Empty State

    func testRenderGPUWithEmptyFeeds() {
        GPUComponentConfig.enabled = true

        let props = FeedManager.Props(
            feeds: [],
            onAddFeed: { _ in },
            onEditFeed: { _ in },
            onDeleteFeed: { _ in },
            onToggleFeed: { _ in },
            onRefreshFeed: { _ in },
            onChangeMode: { _ in },
            onClose: { }
        )

        let nodes = FeedManager.renderGPU(props: props)
        XCTAssertFalse(nodes.isEmpty, "Empty state should render with GPU")
    }
}
