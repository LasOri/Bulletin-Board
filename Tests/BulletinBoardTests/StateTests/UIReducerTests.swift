import XCTest
@testable import BulletinBoard

final class UIReducerTests: XCTestCase {

    // MARK: - Article Expansion Tests

    func test_expandArticle_setsExpandedIdAndAnimation() {
        let state = UIState()

        let newState = uiReducer(state: state, action: UIAction.expandArticle(id: "article-1"))

        XCTAssertEqual(newState.expandedArticleId, "article-1")
        XCTAssertTrue(newState.isAnimating)
    }

    func test_collapseArticle_clearsExpandedIdAndSetsAnimation() {
        var state = UIState()
        state.expandedArticleId = "article-1"
        state.isAnimating = false

        let newState = uiReducer(state: state, action: UIAction.collapseArticle)

        XCTAssertNil(newState.expandedArticleId)
        XCTAssertTrue(newState.isAnimating)
    }

    func test_completeAnimation_setsAnimatingFalse() {
        var state = UIState()
        state.isAnimating = true

        let newState = uiReducer(state: state, action: UIAction.completeAnimation)

        XCTAssertFalse(newState.isAnimating)
    }

    // MARK: - Modal Tests

    func test_openFeedManager_setsFeedManagerOpenTrue() {
        let state = UIState()

        let newState = uiReducer(state: state, action: UIAction.openFeedManager)

        XCTAssertTrue(newState.isFeedManagerOpen)
    }

    func test_closeFeedManager_setsFeedManagerOpenFalse() {
        var state = UIState()
        state.isFeedManagerOpen = true

        let newState = uiReducer(state: state, action: UIAction.closeFeedManager)

        XCTAssertFalse(newState.isFeedManagerOpen)
    }

    func test_toggleSettings_togglesSettingsOpen() {
        var state = UIState()
        state.isSettingsOpen = false

        let newState1 = uiReducer(state: state, action: UIAction.toggleSettings)
        XCTAssertTrue(newState1.isSettingsOpen)

        let newState2 = uiReducer(state: newState1, action: UIAction.toggleSettings)
        XCTAssertFalse(newState2.isSettingsOpen)
    }

    // MARK: - Sidebar Tests

    func test_toggleSidebar_togglesVisibility() {
        var state = UIState()
        state.isSidebarVisible = true

        let newState1 = uiReducer(state: state, action: UIAction.toggleSidebar)
        XCTAssertFalse(newState1.isSidebarVisible)

        let newState2 = uiReducer(state: newState1, action: UIAction.toggleSidebar)
        XCTAssertTrue(newState2.isSidebarVisible)
    }

    func test_showSidebar_setsSidebarVisibleTrue() {
        var state = UIState()
        state.isSidebarVisible = false

        let newState = uiReducer(state: state, action: UIAction.showSidebar)

        XCTAssertTrue(newState.isSidebarVisible)
    }

    func test_hideSidebar_setsSidebarVisibleFalse() {
        var state = UIState()
        state.isSidebarVisible = true

        let newState = uiReducer(state: state, action: UIAction.hideSidebar)

        XCTAssertFalse(newState.isSidebarVisible)
    }

    // MARK: - Theme Tests

    func test_setTheme_updatesTheme() {
        let state = UIState()

        let newState = uiReducer(state: state, action: UIAction.setTheme(.dark))

        XCTAssertEqual(newState.theme, .dark)
    }

    // MARK: - Notification Tests

    func test_showError_setsErrorMessage() {
        let state = UIState()

        let newState = uiReducer(state: state, action: UIAction.showError("Test error"))

        XCTAssertEqual(newState.errorMessage, "Test error")
    }

    func test_clearError_clearsErrorMessage() {
        var state = UIState()
        state.errorMessage = "Test error"

        let newState = uiReducer(state: state, action: UIAction.clearError)

        XCTAssertNil(newState.errorMessage)
    }

    func test_showToast_setsToastMessage() {
        let state = UIState()

        let newState = uiReducer(state: state, action: UIAction.showToast("Test toast"))

        XCTAssertEqual(newState.toastMessage, "Test toast")
    }

    func test_clearToast_clearsToastMessage() {
        var state = UIState()
        state.toastMessage = "Test toast"

        let newState = uiReducer(state: state, action: UIAction.clearToast)

        XCTAssertNil(newState.toastMessage)
    }

    // MARK: - State Immutability Tests

    func test_reducerReturnsNewState_doesNotMutateOriginal() {
        let state = UIState()

        _ = uiReducer(state: state, action: UIAction.expandArticle(id: "article-1"))

        // Original state should remain unchanged
        XCTAssertNil(state.expandedArticleId)
        XCTAssertFalse(state.isAnimating)
    }
}
