import XCTest
@testable import BulletinBoard
import LINKER

final class CSPTests: XCTestCase {

    func test_csp_hasWasmUnsafeEval() {
        let csp = CSPConfiguration.configure()
        XCTAssertTrue(csp.contains("wasm-unsafe-eval"), "CSP should include wasm-unsafe-eval for WASM compilation")
    }

    func test_csp_noUnsafeInlineInScriptSrc() {
        let csp = CSPConfiguration.configure()
        let scriptSrcRange = csp.range(of: "script-src ")
        XCTAssertNotNil(scriptSrcRange, "CSP should contain script-src")

        if let start = scriptSrcRange?.upperBound {
            let rest = String(csp[start...])
            let directiveEnd = rest.firstIndex(of: ";") ?? rest.endIndex
            let scriptSrcValue = String(rest[rest.startIndex..<directiveEnd])
            XCTAssertFalse(scriptSrcValue.contains("'unsafe-inline'"),
                           "script-src should not contain unsafe-inline, got: \(scriptSrcValue)")
        }
    }

    func test_csp_styleAllowsUnsafeInline() {
        let csp = CSPConfiguration.configure()
        XCTAssertTrue(csp.contains("style-src") && csp.contains("'unsafe-inline'"),
                       "style-src should allow unsafe-inline for inline styles")
    }

    func test_csp_hasRequiredDirectives() {
        let csp = CSPConfiguration.configure()
        XCTAssertTrue(csp.contains("default-src 'self'"))
        XCTAssertTrue(csp.contains("object-src 'none'"))
        XCTAssertTrue(csp.contains("frame-ancestors 'none'"))
        XCTAssertTrue(csp.contains("upgrade-insecure-requests"))
    }
}
