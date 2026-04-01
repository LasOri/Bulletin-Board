import XCTest
@testable import BulletinBoard

extension XCTestCase {
    func validateNoInvalidOptionalCalls(
        in filePath: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let content = readSourceFile(filePath, file: file, line: line) else { return }

        let lines = content.components(separatedBy: .newlines)

        for (lineNumber, sourceLine) in lines.enumerated() {
            let trimmed = sourceLine.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("?(") && !trimmed.contains("?()") {
                let hasLeadingOptional = trimmed.contains("?.") || trimmed.contains("try?")
                let isInitDeclaration = trimmed.contains("init?(")
                let isRegexPattern = trimmed.contains("/") && trimmed.contains("?)")

                if !hasLeadingOptional && !isInitDeclaration && !isRegexPattern {
                    XCTFail(
                        "Found potential invalid optional call on non-optional JSValue at \(filePath):\(lineNumber + 1): \(trimmed)",
                        file: file,
                        line: line
                    )
                }
            }
        }
    }
}

final class JSValueOptionalChainingTests: XCTestCase {
    func testNoInvalidOptionalCallOnNonOptionalJSValue() {
        let sourceFiles = [
            "Sources/BulletinBoard/Components/App.swift",
            "Sources/BulletinBoard/Components/CardExpansionController.swift",
            "Sources/BulletinBoard/Security/CSPConfiguration.swift",
            "Sources/BulletinBoard/Services/OPMLService.swift",
            "Sources/BulletinBoard/Services/StorageService.swift"
        ]

        for filePath in sourceFiles {
            validateNoInvalidOptionalCalls(in: filePath)
        }
    }
}
