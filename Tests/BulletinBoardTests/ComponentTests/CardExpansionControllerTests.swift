import XCTest
@testable import BulletinBoard

extension XCTestCase {
    func assertPatternNotFound(
        in sourceFilePath: String,
        pattern: String,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let fileContents = readSourceFile(sourceFilePath, file: file, line: line) else {
            return
        }

        let occurrences = fileContents.components(separatedBy: pattern).count - 1
        XCTAssertEqual(
            occurrences,
            0,
            "Found \(occurrences) occurrences of \(pattern). \(message)",
            file: file,
            line: line
        )
    }

    func assertPatternNotFoundMultiline(
        in sourceFilePath: String,
        pattern: String,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let fileContents = readSourceFile(sourceFilePath, file: file, line: line) else {
            return
        }

        let normalized = fileContents
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")

        var compacted = normalized
        while compacted.contains("  ") {
            compacted = compacted.replacingOccurrences(of: "  ", with: " ")
        }

        let occurrences = compacted.components(separatedBy: pattern).count - 1
        XCTAssertEqual(
            occurrences,
            0,
            "Found \(occurrences) occurrences of multi-line pattern '\(pattern)'. \(message)",
            file: file,
            line: line
        )
    }
}

final class CardExpansionControllerTests: XCTestCase {
    func testCardExpansionControllerUsesThrowingSetProperty() {
        assertPatternNotFound(
            in: "Sources/BulletinBoard/Components/CardExpansionController.swift",
            pattern: ".style.object?.setProperty?",
            message: "Should use try? obj.style.throwing.setProperty? instead."
        )
    }
}
