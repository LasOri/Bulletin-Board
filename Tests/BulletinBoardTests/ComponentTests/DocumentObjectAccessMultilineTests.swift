import XCTest
@testable import BulletinBoard

final class DocumentObjectAccessMultilineTests: XCTestCase {
    func testDocumentObjectAccessWithoutDoubleOptionalChainingMultiline() {
        assertPatternNotFoundMultiline(
            in: "Sources/BulletinBoard/Components/App.swift",
            pattern: "SafeJSGlobal.global?.document.object? .",
            message: "2-level chain global?.document returns non-optional JSValue on WASM (lesson #66). Should use SafeJSGlobal.global?.document.object without ? after the second object."
        )
    }
}
