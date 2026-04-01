import XCTest
@testable import BulletinBoard

extension XCTestCase {
    func readSourceFile(
        _ path: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String? {
        guard let fileURL = URL(string: "file://\(FileManager.default.currentDirectoryPath)/\(path)"),
              let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            XCTFail("Could not read \(path)", file: file, line: line)
            return nil
        }
        return contents
    }
}

final class ConditionalCompilationGuardTests: XCTestCase {
    func testAllJavaScriptKitImportsHaveArchGuard() {
        let files = [
            "Sources/BulletinBoard/Components/App.swift",
            "Sources/BulletinBoard/Components/CardExpansionController.swift"
        ]

        for filePath in files {
            guard let fileContents = readSourceFile(filePath) else { continue }

            let incompleteGuardCount = fileContents
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0 == "#if canImport(JavaScriptKit)" }
                .count

            XCTAssertEqual(
                incompleteGuardCount,
                0,
                "Found \(incompleteGuardCount) incomplete guard(s) in \(filePath). Should use '#if canImport(JavaScriptKit) && arch(wasm32)' to prevent compilation issues during native swift test."
            )
        }
    }
}
