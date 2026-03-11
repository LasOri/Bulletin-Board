import XCTest
@testable import BulletinBoard
import LINKER

final class AppStartupTests: XCTestCase {

    func testAppMainInitializesStore() async {
        // App.main() should work in non-WASM mode
        // (WASM-specific code is guarded with #if canImport guards)
        await App.main()

        // Verify store is initialized with sample data (first-run path)
        let state = appStore.getState()
        XCTAssertFalse(state.feeds.feeds.isEmpty, "Should have at least sample feed")
    }

    func testReducerIntegration() {
        let feed = Feed(
            id: "test",
            title: "Test",
            description: "Test feed",
            url: "https://example.com/feed.xml"
        )
        appStore.dispatch(FeedAction.addFeed(feed))
        let state = appStore.getState()
        XCTAssertTrue(state.feeds.feeds.contains(where: { $0.id == "test" }))
    }

    func testLoggerConfigures() async {
        let sink = MemorySink()
        await Logger.shared.configureForTesting(sink: sink)
        await Logger.shared.info(AppLogFeature.startup, "test message")
        let messages = sink.getMessages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.feature, "APP.STARTUP")
    }
}
