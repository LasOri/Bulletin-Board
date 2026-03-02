import XCTest
@testable import BulletinBoard

final class FeedReducerTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTestFeed(
        id: String = "feed-1",
        title: String = "Test Feed",
        url: String = "https://example.com/feed.xml",
        isEnabled: Bool = true
    ) -> Feed {
        Feed(
            id: id,
            title: title,
            description: "Test feed description",
            url: url,
            isEnabled: isEnabled
        )
    }

    // MARK: - Add Feed Tests

    func test_addFeed_addsToStateAndAllIds() {
        let state = FeedState()
        let feed = makeTestFeed()

        let newState = feedReducer(state: state, action: FeedAction.addFeed(feed))

        XCTAssertEqual(newState.byId.count, 1)
        XCTAssertEqual(newState.allIds.count, 1)
        XCTAssertNotNil(newState.byId[feed.id])
        XCTAssertTrue(newState.allIds.contains(feed.id))
    }

    func test_addFeed_withDuplicateId_doesNotAddDuplicate() {
        var state = FeedState()
        let feed1 = makeTestFeed()
        state.byId[feed1.id] = feed1
        state.allIds = [feed1.id]

        let feed2 = makeTestFeed() // Same ID

        let newState = feedReducer(state: state, action: FeedAction.addFeed(feed2))

        XCTAssertEqual(newState.byId.count, 1)
        XCTAssertEqual(newState.allIds.count, 1)
    }

    // MARK: - Update Feed Tests

    func test_updateFeed_replacesExistingFeed() {
        var state = FeedState()
        let originalFeed = makeTestFeed()
        state.byId[originalFeed.id] = originalFeed
        state.allIds = [originalFeed.id]

        let updatedFeed = Feed(
            id: originalFeed.id,
            title: "Updated Title",
            description: originalFeed.description,
            url: originalFeed.url,
            isEnabled: originalFeed.isEnabled
        )

        let newState = feedReducer(
            state: state,
            action: FeedAction.updateFeed(id: originalFeed.id, updatedFeed)
        )

        XCTAssertEqual(newState.byId[originalFeed.id]?.title, "Updated Title")
    }

    // MARK: - Remove Feed Tests

    func test_removeFeed_removesFromStateAndAllIds() {
        var state = FeedState()
        let feed = makeTestFeed()
        state.byId[feed.id] = feed
        state.allIds = [feed.id]

        let newState = feedReducer(state: state, action: FeedAction.removeFeed(id: feed.id))

        XCTAssertNil(newState.byId[feed.id])
        XCTAssertFalse(newState.allIds.contains(feed.id))
    }

    func test_removeFeed_whenSelected_clearsSelection() {
        var state = FeedState()
        let feed = makeTestFeed()
        state.byId[feed.id] = feed
        state.allIds = [feed.id]
        state.selectedId = feed.id

        let newState = feedReducer(state: state, action: FeedAction.removeFeed(id: feed.id))

        XCTAssertNil(newState.selectedId)
    }

    func test_removeFeed_removesFetchingStatus() {
        var state = FeedState()
        let feed = makeTestFeed()
        state.byId[feed.id] = feed
        state.allIds = [feed.id]
        state.fetchingIds.insert(feed.id)

        let newState = feedReducer(state: state, action: FeedAction.removeFeed(id: feed.id))

        XCTAssertFalse(newState.fetchingIds.contains(feed.id))
    }

    // MARK: - Toggle Enabled Tests

    func test_toggleFeedEnabled_whenEnabled_disablesFeed() {
        var state = FeedState()
        let feed = makeTestFeed(isEnabled: true)
        state.byId[feed.id] = feed
        state.allIds = [feed.id]

        let newState = feedReducer(state: state, action: FeedAction.toggleFeedEnabled(id: feed.id))

        XCTAssertFalse(newState.byId[feed.id]!.isEnabled)
    }

    func test_toggleFeedEnabled_whenDisabled_enablesFeed() {
        var state = FeedState()
        let feed = makeTestFeed(isEnabled: false)
        state.byId[feed.id] = feed
        state.allIds = [feed.id]

        let newState = feedReducer(state: state, action: FeedAction.toggleFeedEnabled(id: feed.id))

        XCTAssertTrue(newState.byId[feed.id]!.isEnabled)
    }

    // MARK: - Select Feed Tests

    func test_selectFeed_setsSelectedId() {
        let state = FeedState()

        let newState = feedReducer(state: state, action: FeedAction.selectFeed(id: "feed-1"))

        XCTAssertEqual(newState.selectedId, "feed-1")
    }

    func test_selectFeed_withNil_clearsSelection() {
        var state = FeedState()
        state.selectedId = "feed-1"

        let newState = feedReducer(state: state, action: FeedAction.selectFeed(id: nil))

        XCTAssertNil(newState.selectedId)
    }

    // MARK: - Fetching Tests

    func test_startFetching_addsFeedIdToFetchingSet() {
        var state = FeedState()
        let feed = makeTestFeed()
        state.byId[feed.id] = feed
        state.allIds = [feed.id]

        let newState = feedReducer(state: state, action: FeedAction.startFetching(id: feed.id))

        XCTAssertTrue(newState.fetchingIds.contains(feed.id))
        XCTAssertTrue(newState.byId[feed.id]!.isFetching)
        XCTAssertNotNil(newState.byId[feed.id]!.lastFetched)
    }

    func test_completeFetch_removesFeedIdFromFetchingSet() {
        var state = FeedState()
        var feed = makeTestFeed()
        feed.isFetching = true
        state.byId[feed.id] = feed
        state.allIds = [feed.id]
        state.fetchingIds.insert(feed.id)

        let newState = feedReducer(
            state: state,
            action: FeedAction.completeFetch(id: feed.id, articleCount: 10)
        )

        XCTAssertFalse(newState.fetchingIds.contains(feed.id))
        XCTAssertFalse(newState.byId[feed.id]!.isFetching)
        XCTAssertEqual(newState.byId[feed.id]!.articleCount, 10)
        XCTAssertNotNil(newState.byId[feed.id]!.lastSuccessfulFetch)
        XCTAssertNil(newState.byId[feed.id]!.lastError)
    }

    func test_failFetch_removesFeedIdAndSetsError() {
        var state = FeedState()
        var feed = makeTestFeed()
        feed.isFetching = true
        state.byId[feed.id] = feed
        state.allIds = [feed.id]
        state.fetchingIds.insert(feed.id)

        let errorMessage = "Network error"
        let newState = feedReducer(
            state: state,
            action: FeedAction.failFetch(id: feed.id, error: errorMessage)
        )

        XCTAssertFalse(newState.fetchingIds.contains(feed.id))
        XCTAssertFalse(newState.byId[feed.id]!.isFetching)
        XCTAssertEqual(newState.byId[feed.id]!.lastError, errorMessage)
    }

    // MARK: - Unread Count Tests

    func test_updateUnreadCount_updatesCount() {
        var state = FeedState()
        let feed = makeTestFeed()
        state.byId[feed.id] = feed
        state.allIds = [feed.id]

        let newState = feedReducer(
            state: state,
            action: FeedAction.updateUnreadCount(feedId: feed.id, count: 5)
        )

        XCTAssertEqual(newState.byId[feed.id]!.unreadCount, 5)
    }

    func test_recalculateAllUnreadCounts_updatesAllFeeds() {
        var state = FeedState()
        let feed1 = makeTestFeed(id: "feed-1")
        let feed2 = makeTestFeed(id: "feed-2")
        state.byId = [feed1.id: feed1, feed2.id: feed2]
        state.allIds = [feed1.id, feed2.id]

        let counts = [feed1.id: 3, feed2.id: 7]
        let newState = feedReducer(
            state: state,
            action: FeedAction.recalculateAllUnreadCounts(counts)
        )

        XCTAssertEqual(newState.byId[feed1.id]!.unreadCount, 3)
        XCTAssertEqual(newState.byId[feed2.id]!.unreadCount, 7)
    }

    // MARK: - State Immutability Tests

    func test_reducerReturnsNewState_doesNotMutateOriginal() {
        let state = FeedState()
        let feed = makeTestFeed()

        _ = feedReducer(state: state, action: FeedAction.addFeed(feed))

        // Original state should remain empty
        XCTAssertTrue(state.byId.isEmpty)
        XCTAssertTrue(state.allIds.isEmpty)
    }
}
