import XCTest
@testable import BulletinBoard

final class DatasetAccessTests: XCTestCase {
    func testDatasetObjectAccessWithoutOptionalChaining() {
        assertPatternNotFound(
            in: "Sources/BulletinBoard/Components/App.swift",
            pattern: ".dataset.object?[",
            message: "2-level JSValue chains return non-optional on WASM. Should use .dataset.object[ without optional chaining."
        )
    }
}
