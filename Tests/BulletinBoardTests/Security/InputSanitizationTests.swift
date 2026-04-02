import XCTest
@testable import BulletinBoard

final class InputSanitizationTests: XCTestCase {

    func test_sanitizeText_escapesHTMLEntities() {
        XCTAssertEqual(InputSanitizer.sanitizeText("<script>alert('xss')</script>"),
                       "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;")
    }

    func test_sanitizeText_escapesAmpersand() {
        XCTAssertEqual(InputSanitizer.sanitizeText("Tom & Jerry"), "Tom &amp; Jerry")
    }

    func test_sanitizeText_escapesDoubleQuotes() {
        XCTAssertEqual(InputSanitizer.sanitizeText("say \"hello\""), "say &quot;hello&quot;")
    }

    func test_sanitizeText_preservesNormalText() {
        XCTAssertEqual(InputSanitizer.sanitizeText("Hello World"), "Hello World")
    }

    func test_sanitizeText_handlesEmptyString() {
        XCTAssertEqual(InputSanitizer.sanitizeText(""), "")
    }

    func test_sanitizeURL_allowsHTTPS() {
        let url = "https://example.com/feed.xml"
        let result = InputSanitizer.sanitizeURL(url)
        XCTAssertTrue(result.contains("https://example.com"))
    }

    func test_sanitizeURL_allowsHTTP() {
        let url = "http://example.com/feed.xml"
        let result = InputSanitizer.sanitizeURL(url)
        XCTAssertTrue(result.contains("http://example.com"))
    }

    func test_sanitizeURL_rejectsJavascript() {
        XCTAssertEqual(InputSanitizer.sanitizeURL("javascript:alert(1)"), "#")
    }

    func test_sanitizeURL_rejectsJavascriptMixedCase() {
        XCTAssertEqual(InputSanitizer.sanitizeURL("JavaScript:alert(1)"), "#")
    }

    func test_sanitizeURL_rejectsData() {
        XCTAssertEqual(InputSanitizer.sanitizeURL("data:text/html,<script>alert(1)</script>"), "#")
    }

    func test_sanitizeURL_rejectsVBScript() {
        XCTAssertEqual(InputSanitizer.sanitizeURL("vbscript:MsgBox"), "#")
    }

    func test_sanitizeURL_rejectsEmpty() {
        XCTAssertEqual(InputSanitizer.sanitizeURL(""), "#")
    }

    func test_sanitizeURL_rejectsRelativePaths() {
        XCTAssertEqual(InputSanitizer.sanitizeURL("/path/to/page"), "#")
    }

    func test_sanitizeURL_preservesValidURLWithSpecialChars() {
        let url = "https://example.com/search?q=test&page=1"
        let result = InputSanitizer.sanitizeURL(url)
        XCTAssertEqual(result, url)
    }

    func test_sanitizeURL_trimsWhitespace() {
        let url = "  https://example.com  "
        let result = InputSanitizer.sanitizeURL(url)
        XCTAssertTrue(result.hasPrefix("https://"))
    }
}
