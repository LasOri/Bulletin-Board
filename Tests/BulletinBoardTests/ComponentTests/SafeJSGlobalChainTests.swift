import XCTest
@testable import BulletinBoard

final class SafeJSGlobalChainTests: XCTestCase {
    func testSafeJSGlobalScrollToUsesFunction() {
        assertPatternNotFound(
            in: "Sources/BulletinBoard/Components/App.swift",
            pattern: "SafeJSGlobal.global?.scrollTo?(",
            message: "Should use SafeJSGlobal.global?.scrollTo.function?() instead to properly check function existence."
        )
    }

    func testSafeJSGlobalQueueMicrotaskUsesTry() {
        assertPatternNotFound(
            in: "Sources/BulletinBoard/Components/App.swift",
            pattern: "_ = SafeJSGlobal.global?.queueMicrotask.function?",
            message: "Should wrap SafeJSGlobal.global?.queueMicrotask.function? with try? to catch JS exceptions safely (queueMicrotask can throw if callback is invalid)."
        )
    }
}
