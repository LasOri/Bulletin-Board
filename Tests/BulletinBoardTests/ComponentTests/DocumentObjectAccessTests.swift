import XCTest
@testable import BulletinBoard

final class DocumentObjectAccessTests: XCTestCase {
    func testDocumentObjectAccessUsesOptionalChaining() {
        assertPatternNotFound(
            in: "Sources/BulletinBoard/Components/App.swift",
            pattern: "SafeJSGlobal.global?.document.object.",
            message: "JSValue.object returns JSObject? — must use document.object?. with optional chaining to access members safely."
        )
    }
}
