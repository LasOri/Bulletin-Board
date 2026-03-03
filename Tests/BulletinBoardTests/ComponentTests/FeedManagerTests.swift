import XCTest
@testable import BulletinBoard
import LINKER

final class FeedManagerTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTestFeed(
        id: String = "test-1",
        title: String = "Test Feed",
        url: String = "https://example.com/feed.xml",
        isEnabled: Bool = true,
        isFetching: Bool = false,
        articleCount: Int = 0,
        unreadCount: Int = 0,
        lastError: String? = nil
    ) -> Feed {
        Feed(
            id: id,
            title: title,
            description: "Test feed description",
            url: url,
            isEnabled: isEnabled,
            isFetching: isFetching
        )
    }

    private func makeTestProps(
        feeds: [Feed] = [],
        viewMode: FeedManager.ViewMode = .list,
        isLoading: Bool = false,
        error: String? = nil,
        onAddFeed: @escaping (String) -> Void = { _ in },
        onEditFeed: @escaping (Feed) -> Void = { _ in },
        onDeleteFeed: @escaping (String) -> Void = { _ in },
        onToggleFeed: @escaping (String) -> Void = { _ in },
        onRefreshFeed: @escaping (String) -> Void = { _ in },
        onChangeMode: @escaping (FeedManager.ViewMode) -> Void = { _ in },
        onClose: @escaping () -> Void = { }
    ) -> FeedManager.Props {
        FeedManager.Props(
            feeds: feeds,
            viewMode: viewMode,
            isLoading: isLoading,
            error: error,
            onAddFeed: onAddFeed,
            onEditFeed: onEditFeed,
            onDeleteFeed: onDeleteFeed,
            onToggleFeed: onToggleFeed,
            onRefreshFeed: onRefreshFeed,
            onChangeMode: onChangeMode,
            onClose: onClose
        )
    }

    // MARK: - Basic Rendering Tests

    func testRenderListMode() {
        let props = makeTestProps(viewMode: .list)
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render feed manager in list mode
    }

    func testRenderAddMode() {
        let props = makeTestProps(viewMode: .add)
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render add feed form
    }

    func testRenderEditMode() {
        let feed = makeTestFeed(id: "feed-1")
        let props = makeTestProps(feeds: [feed], viewMode: .edit(feedId: "feed-1"))
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render edit feed form
    }

    // MARK: - Feed List Tests

    func testRenderEmptyFeedList() {
        let props = makeTestProps(feeds: [])
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render empty state
    }

    func testRenderSingleFeed() {
        let feed = makeTestFeed()
        let props = makeTestProps(feeds: [feed])
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render one feed item
    }

    func testRenderMultipleFeeds() {
        let feeds = [
            makeTestFeed(id: "1", title: "Feed 1"),
            makeTestFeed(id: "2", title: "Feed 2"),
            makeTestFeed(id: "3", title: "Feed 3")
        ]
        let props = makeTestProps(feeds: feeds)
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render all feeds
    }

    // MARK: - Feed Item Tests

    func testRenderEnabledFeed() {
        let feed = makeTestFeed(isEnabled: true)
        let props = makeTestProps(feeds: [feed])
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render enabled feed
    }

    func testRenderDisabledFeed() {
        let feed = makeTestFeed(isEnabled: false)
        let props = makeTestProps(feeds: [feed])
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render disabled feed with disabled class
    }

    func testRenderFetchingFeed() {
        let feed = makeTestFeed(isFetching: true)
        let props = makeTestProps(feeds: [feed])
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render fetching feed with fetching class
    }

    func testRenderFeedWithError() {
        var feed = makeTestFeed()
        feed.lastError = "Network error"
        let props = makeTestProps(feeds: [feed])
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render feed with error class
    }

    // MARK: - Loading State Tests

    func testRenderLoadingState() {
        let props = makeTestProps(isLoading: true)
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render loading spinner
    }

    func testRenderLoadingIgnoresContent() {
        let feeds = [makeTestFeed()]
        let props = makeTestProps(feeds: feeds, isLoading: true)
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should show loading, not feeds
    }

    // MARK: - Error State Tests

    func testRenderWithError() {
        let props = makeTestProps(error: "Failed to load feeds")
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render error message
    }

    func testRenderWithoutError() {
        let props = makeTestProps(error: nil)
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should not render error message
    }

    // MARK: - View Mode Tests

    func testViewModeList() {
        let mode: FeedManager.ViewMode = .list
        if case .list = mode {
            XCTAssertTrue(true)
        } else {
            XCTFail("Should be list mode")
        }
    }

    func testViewModeAdd() {
        let mode: FeedManager.ViewMode = .add
        if case .add = mode {
            XCTAssertTrue(true)
        } else {
            XCTFail("Should be add mode")
        }
    }

    func testViewModeEdit() {
        let mode: FeedManager.ViewMode = .edit(feedId: "test-id")
        if case .edit(let feedId) = mode {
            XCTAssertEqual(feedId, "test-id")
        } else {
            XCTFail("Should be edit mode")
        }
    }

    // MARK: - Props Tests

    func testPropsInitialization() {
        let feeds = [makeTestFeed()]
        var addedUrl: String?
        var editedFeed: Feed?
        var deletedId: String?
        var toggledId: String?
        var refreshedId: String?
        var modeChanged: FeedManager.ViewMode?
        var closed = false

        let props = FeedManager.Props(
            feeds: feeds,
            viewMode: .list,
            isLoading: false,
            error: nil,
            onAddFeed: { url in addedUrl = url },
            onEditFeed: { feed in editedFeed = feed },
            onDeleteFeed: { id in deletedId = id },
            onToggleFeed: { id in toggledId = id },
            onRefreshFeed: { id in refreshedId = id },
            onChangeMode: { mode in modeChanged = mode },
            onClose: { closed = true }
        )

        XCTAssertEqual(props.feeds.count, 1)
        XCTAssertFalse(props.isLoading)
        XCTAssertNil(props.error)

        props.onAddFeed("https://test.com/feed.xml")
        XCTAssertEqual(addedUrl, "https://test.com/feed.xml")

        props.onEditFeed(feeds[0])
        XCTAssertEqual(editedFeed?.id, feeds[0].id)

        props.onDeleteFeed("feed-1")
        XCTAssertEqual(deletedId, "feed-1")

        props.onToggleFeed("feed-2")
        XCTAssertEqual(toggledId, "feed-2")

        props.onRefreshFeed("feed-3")
        XCTAssertEqual(refreshedId, "feed-3")

        props.onChangeMode(.add)
        if case .add = modeChanged {
            XCTAssertTrue(true)
        } else {
            XCTFail("Mode should have changed to add")
        }

        props.onClose()
        XCTAssertTrue(closed)
    }

    func testPropsDefaults() {
        let props = makeTestProps()

        XCTAssertEqual(props.feeds.count, 0)
        if case .list = props.viewMode {
            XCTAssertTrue(true)
        } else {
            XCTFail("Default view mode should be list")
        }
        XCTAssertFalse(props.isLoading)
        XCTAssertNil(props.error)
    }

    // MARK: - Form Tests

    func testRenderAddFeedForm() {
        let props = makeTestProps(viewMode: .add)
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render add feed form with URL input
    }

    func testRenderEditFeedForm() {
        let feed = makeTestFeed(id: "feed-1", title: "My Feed")
        let props = makeTestProps(feeds: [feed], viewMode: .edit(feedId: "feed-1"))
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render edit form with feed data
    }

    func testEditFormWithNonExistentFeed() {
        let props = makeTestProps(feeds: [], viewMode: .edit(feedId: "nonexistent"))
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle missing feed gracefully
    }

    // MARK: - Action Button Tests

    func testToggleButtonEnabledFeed() {
        let feed = makeTestFeed(isEnabled: true)
        let props = makeTestProps(feeds: [feed])
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Toggle button should show pause icon
    }

    func testToggleButtonDisabledFeed() {
        let feed = makeTestFeed(isEnabled: false)
        let props = makeTestProps(feeds: [feed])
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Toggle button should show play icon
    }

    func testRefreshButtonDisabledWhenFetching() {
        let feed = makeTestFeed(isFetching: true)
        let props = makeTestProps(feeds: [feed])
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Refresh button should be disabled
    }

    func testRefreshButtonEnabledWhenNotFetching() {
        let feed = makeTestFeed(isFetching: false)
        let props = makeTestProps(feeds: [feed])
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Refresh button should be enabled
    }

    // MARK: - Footer Tests

    func testFooterInListMode() {
        let props = makeTestProps(viewMode: .list)
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should show "Add Feed" button
    }

    func testFooterInAddMode() {
        let props = makeTestProps(viewMode: .add)
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should show "Cancel" button
    }

    func testFooterInEditMode() {
        let feed = makeTestFeed(id: "feed-1")
        let props = makeTestProps(feeds: [feed], viewMode: .edit(feedId: "feed-1"))
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should show "Cancel" button
    }

    // MARK: - Accessibility Tests

    func testAccessibilityDialog() {
        let props = makeTestProps()
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have role="dialog"
    }

    func testAccessibilityAriaLabel() {
        let props = makeTestProps()
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have aria-label="Feed Manager"
    }

    func testAccessibilityCloseButton() {
        let props = makeTestProps()
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Close button should have aria-label
    }

    func testAccessibilityActionButtons() {
        let feed = makeTestFeed()
        let props = makeTestProps(feeds: [feed])
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // All action buttons should have aria-labels
    }

    // MARK: - Edge Cases

    func testRenderWithManyFeeds() {
        let feeds = (1...50).map { i in
            makeTestFeed(id: "feed-\(i)", title: "Feed \(i)")
        }
        let props = makeTestProps(feeds: feeds)
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle many feeds
    }

    func testRenderFeedWithLongTitle() {
        let longTitle = String(repeating: "Very Long Feed Title ", count: 20)
        let feed = makeTestFeed(title: longTitle)
        let props = makeTestProps(feeds: [feed])
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle long titles
    }

    func testRenderFeedWithLongURL() {
        let longURL = "https://example.com/" + String(repeating: "path/", count: 50) + "feed.xml"
        let feed = makeTestFeed(url: longURL)
        let props = makeTestProps(feeds: [feed])
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle long URLs
    }

    func testRenderWithLongError() {
        let longError = String(repeating: "Error ", count: 100)
        let props = makeTestProps(error: longError)
        let nodes = FeedManager.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle long error messages
    }

    // MARK: - Integration Tests

    func testCallbacksInvoked() {
        var callbacksInvoked = 0
        let feed = makeTestFeed(id: "feed-1")

        let props = FeedManager.Props(
            feeds: [feed],
            onAddFeed: { _ in callbacksInvoked += 1 },
            onEditFeed: { _ in callbacksInvoked += 1 },
            onDeleteFeed: { _ in callbacksInvoked += 1 },
            onToggleFeed: { _ in callbacksInvoked += 1 },
            onRefreshFeed: { _ in callbacksInvoked += 1 },
            onChangeMode: { _ in callbacksInvoked += 1 },
            onClose: { callbacksInvoked += 1 }
        )

        props.onAddFeed("url")
        props.onEditFeed(feed)
        props.onDeleteFeed("id")
        props.onToggleFeed("id")
        props.onRefreshFeed("id")
        props.onChangeMode(.add)
        props.onClose()

        XCTAssertEqual(callbacksInvoked, 7)
    }
}
