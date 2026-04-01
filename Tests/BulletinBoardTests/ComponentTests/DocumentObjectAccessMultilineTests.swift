import XCTest
@testable import BulletinBoard

final class DocumentObjectAccessMultilineTests: XCTestCase {
    func testDocumentObjectAccessUsesOptionalChainingMultiline() {
        assertPatternNotFoundMultiline(
            in: "Sources/BulletinBoard/Components/App.swift",
            pattern: "SafeJSGlobal.global?.document.object .",
            message: "JSValue.object returns JSObject? — must use document.object?. with optional chaining, not document.object . (without ?)."
        )
    }
}
