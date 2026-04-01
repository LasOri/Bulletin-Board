import XCTest
@testable import BulletinBoard

final class DatasetAccessTests: XCTestCase {
    func testDatasetObjectAccessUsesOptionalChaining() {
        assertPatternNotFound(
            in: "Sources/BulletinBoard/Components/App.swift",
            pattern: ".dataset.object[",
            message: "JSValue.object returns JSObject? — must use .dataset.object?[ with optional chaining to subscript safely."
        )
    }
}
