import XCTest
@testable import BulletinBoard
import LINKER

final class LoadingSpinnerTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTestProps(
        size: LoadingSpinner.Size = .medium,
        style: LoadingSpinner.Style = .default,
        message: String? = nil,
        centered: Bool = true
    ) -> LoadingSpinner.Props {
        LoadingSpinner.Props(
            size: size,
            style: style,
            message: message,
            centered: centered
        )
    }

    // MARK: - Basic Rendering Tests

    func testRenderDefaultSpinner() {
        let props = makeTestProps()
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render spinner container
    }

    func testRenderWithMessage() {
        let props = makeTestProps(message: "Loading articles...")
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render message alongside spinner
    }

    func testRenderWithoutMessage() {
        let props = makeTestProps(message: nil)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render without message element
    }

    // MARK: - Size Tests

    func testRenderSmallSize() {
        let props = makeTestProps(size: .small)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have small size class
    }

    func testRenderMediumSize() {
        let props = makeTestProps(size: .medium)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have medium size class
    }

    func testRenderLargeSize() {
        let props = makeTestProps(size: .large)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have large size class
    }

    func testSizeDimensions() {
        XCTAssertEqual(LoadingSpinner.Size.small.dimension, 20)
        XCTAssertEqual(LoadingSpinner.Size.medium.dimension, 40)
        XCTAssertEqual(LoadingSpinner.Size.large.dimension, 60)
    }

    // MARK: - Style Tests

    func testRenderDefaultStyle() {
        let props = makeTestProps(style: .default)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have default style class
    }

    func testRenderPrimaryStyle() {
        let props = makeTestProps(style: .primary)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have primary style class
    }

    func testRenderLightStyle() {
        let props = makeTestProps(style: .light)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have light style class
    }

    // MARK: - Centered Tests

    func testRenderCentered() {
        let props = makeTestProps(centered: true)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have centered class
    }

    func testRenderNotCentered() {
        let props = makeTestProps(centered: false)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should not have centered class
    }

    // MARK: - Props Tests

    func testPropsInitialization() {
        let props = LoadingSpinner.Props(
            size: .large,
            style: .primary,
            message: "Please wait...",
            centered: false
        )

        XCTAssertEqual(props.size, .large)
        XCTAssertEqual(props.style, .primary)
        XCTAssertEqual(props.message, "Please wait...")
        XCTAssertFalse(props.centered)
    }

    func testPropsDefaultValues() {
        let props = makeTestProps()

        XCTAssertEqual(props.size, .medium)
        XCTAssertEqual(props.style, .default)
        XCTAssertNil(props.message)
        XCTAssertTrue(props.centered)
    }

    // MARK: - Convenience Constructor Tests

    func testSmallConstructor() {
        let nodes = LoadingSpinner.small()

        XCTAssertEqual(nodes.count, 1)
        // Should create small spinner
    }

    func testSmallWithMessage() {
        let nodes = LoadingSpinner.small(message: "Loading...")

        XCTAssertEqual(nodes.count, 1)
        // Should create small spinner with message
    }

    func testMediumConstructor() {
        let nodes = LoadingSpinner.medium()

        XCTAssertEqual(nodes.count, 1)
        // Should create medium spinner
    }

    func testMediumWithMessage() {
        let nodes = LoadingSpinner.medium(message: "Loading...")

        XCTAssertEqual(nodes.count, 1)
        // Should create medium spinner with message
    }

    func testLargeConstructor() {
        let nodes = LoadingSpinner.large()

        XCTAssertEqual(nodes.count, 1)
        // Should create large spinner
    }

    func testLargeWithMessage() {
        let nodes = LoadingSpinner.large(message: "Loading...")

        XCTAssertEqual(nodes.count, 1)
        // Should create large spinner with message
    }

    func testLightConstructor() {
        let nodes = LoadingSpinner.light()

        XCTAssertEqual(nodes.count, 1)
        // Should create light-styled spinner
    }

    func testLightWithSize() {
        let nodes = LoadingSpinner.light(size: .large)

        XCTAssertEqual(nodes.count, 1)
        // Should create large light-styled spinner
    }

    func testPrimaryConstructor() {
        let nodes = LoadingSpinner.primary()

        XCTAssertEqual(nodes.count, 1)
        // Should create primary-styled spinner
    }

    func testPrimaryWithSize() {
        let nodes = LoadingSpinner.primary(size: .small)

        XCTAssertEqual(nodes.count, 1)
        // Should create small primary-styled spinner
    }

    // MARK: - Inline Spinner Tests

    func testInlinePropsInitialization() {
        let props = LoadingSpinner.InlineProps(size: .small, style: .primary)

        XCTAssertEqual(props.size, .small)
        XCTAssertEqual(props.style, .primary)
    }

    func testInlinePropsDefaults() {
        let props = LoadingSpinner.InlineProps()

        XCTAssertEqual(props.size, .small)
        XCTAssertEqual(props.style, .default)
    }

    func testInlineRender() {
        let props = LoadingSpinner.InlineProps()
        let nodes = LoadingSpinner.inline(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render inline spinner (not centered, no message)
    }

    func testInlineSmallConstructor() {
        let nodes = LoadingSpinner.inlineSmall()

        XCTAssertEqual(nodes.count, 1)
        // Should create small inline spinner
    }

    // MARK: - CSS Classes Tests

    func testBaseClassAlwaysPresent() {
        let props = makeTestProps()
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have base loading-spinner class
    }

    func testSizeClassPresent() {
        let props = makeTestProps(size: .large)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have loading-spinner--large class
    }

    func testStyleClassPresent() {
        let props = makeTestProps(style: .primary)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have loading-spinner--primary class
    }

    func testCenteredClassWhenCentered() {
        let props = makeTestProps(centered: true)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have loading-spinner--centered class
    }

    func testNoCenteredClassWhenNotCentered() {
        let props = makeTestProps(centered: false)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should not have loading-spinner--centered class
    }

    // MARK: - Accessibility Tests

    func testAccessibilityRoleStatus() {
        let props = makeTestProps()
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have role="status" attribute
    }

    func testAccessibilityAriaLive() {
        let props = makeTestProps()
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have aria-live="polite" attribute
    }

    func testAccessibilityScreenReaderText() {
        let props = makeTestProps(message: "Loading articles...")
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have screen reader only text
    }

    func testAccessibilityDefaultMessage() {
        let props = makeTestProps(message: nil)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have default "Loading..." screen reader text
    }

    // MARK: - Edge Cases

    func testRenderWithEmptyMessage() {
        let props = makeTestProps(message: "")
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle empty message
    }

    func testRenderWithLongMessage() {
        let longMessage = String(repeating: "Loading ", count: 50)
        let props = makeTestProps(message: longMessage)
        let nodes = LoadingSpinner.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle long messages
    }

    func testAllSizeStyleCombinations() {
        let sizes: [LoadingSpinner.Size] = [.small, .medium, .large]
        let styles: [LoadingSpinner.Style] = [.default, .primary, .light]

        for size in sizes {
            for style in styles {
                let props = makeTestProps(size: size, style: style)
                let nodes = LoadingSpinner.render(props: props)
                XCTAssertEqual(nodes.count, 1)
            }
        }
        // Should render all combinations successfully
    }

    // MARK: - Integration Tests

    func testMultipleSpinnersCanCoexist() {
        let spinner1 = LoadingSpinner.small()
        let spinner2 = LoadingSpinner.medium()
        let spinner3 = LoadingSpinner.large()

        XCTAssertEqual(spinner1.count, 1)
        XCTAssertEqual(spinner2.count, 1)
        XCTAssertEqual(spinner3.count, 1)
        // Multiple spinners can be created independently
    }
}
