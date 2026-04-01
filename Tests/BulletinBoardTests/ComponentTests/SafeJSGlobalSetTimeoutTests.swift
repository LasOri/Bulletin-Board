import XCTest
@testable import BulletinBoard

final class SafeJSGlobalSetTimeoutTests: XCTestCase {
    func testSafeJSGlobalSetTimeoutUsesTry() {
        assertPatternNotFound(
            in: "Sources/BulletinBoard/Components/App.swift",
            pattern: "SafeJSGlobal.global?.setTimeout.function?(",
            message: "Should wrap SafeJSGlobal.global?.setTimeout.function? with try? to catch JS exceptions safely (memory lesson #56: if function exists and throws during execution, becomes WASM unreachable trap)."
        )
    }
}
