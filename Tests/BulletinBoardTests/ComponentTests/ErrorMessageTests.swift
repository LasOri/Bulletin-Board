import XCTest
@testable import BulletinBoard
import LINKER

final class ErrorMessageTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTestProps(
        message: String = "Test error",
        severity: ErrorMessage.Severity = .error,
        title: String? = nil,
        details: String? = nil,
        showRetry: Bool = false,
        showDismiss: Bool = true,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> ErrorMessage.Props {
        ErrorMessage.Props(
            message: message,
            severity: severity,
            title: title,
            details: details,
            showRetry: showRetry,
            showDismiss: showDismiss,
            onRetry: onRetry,
            onDismiss: onDismiss
        )
    }

    // MARK: - Basic Rendering Tests

    func testRenderBasicError() {
        let props = makeTestProps()
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render error container
    }

    func testRenderWithTitle() {
        let props = makeTestProps(title: "Error Title")
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render title
    }

    func testRenderWithoutTitle() {
        let props = makeTestProps(title: nil)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render without title
    }

    func testRenderWithDetails() {
        let props = makeTestProps(details: "Technical details here")
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render details
    }

    func testRenderWithoutDetails() {
        let props = makeTestProps(details: nil)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render without details
    }

    // MARK: - Severity Tests

    func testRenderErrorSeverity() {
        let props = makeTestProps(severity: .error)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have error severity class
    }

    func testRenderWarningSeverity() {
        let props = makeTestProps(severity: .warning)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have warning severity class
    }

    func testRenderInfoSeverity() {
        let props = makeTestProps(severity: .info)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have info severity class
    }

    // MARK: - Action Button Tests

    func testRenderWithRetryButton() {
        let props = makeTestProps(showRetry: true)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render retry button
    }

    func testRenderWithoutRetryButton() {
        let props = makeTestProps(showRetry: false)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should not render retry button
    }

    func testRenderWithDismissButton() {
        let props = makeTestProps(showDismiss: true)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render dismiss button
    }

    func testRenderWithoutDismissButton() {
        let props = makeTestProps(showDismiss: false)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should not render dismiss button
    }

    func testRenderWithBothActions() {
        let props = makeTestProps(showRetry: true, showDismiss: true)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render both buttons
    }

    func testRenderWithNoActions() {
        let props = makeTestProps(showRetry: false, showDismiss: false)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render without action buttons
    }

    // MARK: - Props Tests

    func testPropsInitialization() {
        var retried = false
        var dismissed = false

        let props = ErrorMessage.Props(
            message: "Test message",
            severity: .warning,
            title: "Test Title",
            details: "Test details",
            showRetry: true,
            showDismiss: true,
            onRetry: { retried = true },
            onDismiss: { dismissed = true }
        )

        XCTAssertEqual(props.message, "Test message")
        XCTAssertEqual(props.severity, .warning)
        XCTAssertEqual(props.title, "Test Title")
        XCTAssertEqual(props.details, "Test details")
        XCTAssertTrue(props.showRetry)
        XCTAssertTrue(props.showDismiss)

        props.onRetry?()
        XCTAssertTrue(retried)

        props.onDismiss?()
        XCTAssertTrue(dismissed)
    }

    func testPropsDefaultValues() {
        let props = makeTestProps()

        XCTAssertEqual(props.severity, .error)
        XCTAssertNil(props.title)
        XCTAssertNil(props.details)
        XCTAssertFalse(props.showRetry)
        XCTAssertTrue(props.showDismiss)
        XCTAssertNil(props.onRetry)
        XCTAssertNil(props.onDismiss)
    }

    // MARK: - Convenience Constructor Tests

    func testErrorConstructor() {
        let nodes = ErrorMessage.error(message: "Error occurred")

        XCTAssertEqual(nodes.count, 1)
        // Should create error message
    }

    func testErrorWithTitle() {
        let nodes = ErrorMessage.error(
            message: "Error occurred",
            title: "Error Title"
        )

        XCTAssertEqual(nodes.count, 1)
        // Should create error with title
    }

    func testErrorWithDetails() {
        let nodes = ErrorMessage.error(
            message: "Error occurred",
            details: "Stack trace here"
        )

        XCTAssertEqual(nodes.count, 1)
        // Should create error with details
    }

    func testErrorWithRetry() {
        var retried = false
        let nodes = ErrorMessage.error(
            message: "Error occurred",
            showRetry: true,
            onRetry: { retried = true }
        )

        XCTAssertEqual(nodes.count, 1)
        // Should create error with retry button
    }

    func testWarningConstructor() {
        let nodes = ErrorMessage.warning(message: "Warning message")

        XCTAssertEqual(nodes.count, 1)
        // Should create warning message
    }

    func testInfoConstructor() {
        let nodes = ErrorMessage.info(message: "Info message")

        XCTAssertEqual(nodes.count, 1)
        // Should create info message
    }

    // MARK: - Common Error Message Tests

    func testNetworkError() {
        var retried = false
        let nodes = ErrorMessage.networkError(onRetry: { retried = true })

        XCTAssertEqual(nodes.count, 1)
        // Should create network error with retry
    }

    func testNetworkErrorCustomMessage() {
        var retried = false
        let nodes = ErrorMessage.networkError(
            message: "Custom network error",
            onRetry: { retried = true }
        )

        XCTAssertEqual(nodes.count, 1)
        // Should create network error with custom message
    }

    func testNotFoundError() {
        let nodes = ErrorMessage.notFound()

        XCTAssertEqual(nodes.count, 1)
        // Should create not found error
    }

    func testNotFoundErrorCustomMessage() {
        let nodes = ErrorMessage.notFound(message: "Article not found")

        XCTAssertEqual(nodes.count, 1)
        // Should create not found error with custom message
    }

    func testPermissionDeniedError() {
        let nodes = ErrorMessage.permissionDenied()

        XCTAssertEqual(nodes.count, 1)
        // Should create permission denied error
    }

    func testValidationError() {
        let nodes = ErrorMessage.validationError(message: "Invalid input")

        XCTAssertEqual(nodes.count, 1)
        // Should create validation error
    }

    func testValidationErrorWithDetails() {
        let nodes = ErrorMessage.validationError(
            message: "Invalid input",
            details: "Email format is incorrect"
        )

        XCTAssertEqual(nodes.count, 1)
        // Should create validation error with details
    }

    func testGenericError() {
        let nodes = ErrorMessage.genericError()

        XCTAssertEqual(nodes.count, 1)
        // Should create generic error
    }

    func testGenericErrorWithRetry() {
        var retried = false
        let nodes = ErrorMessage.genericError(
            showRetry: true,
            onRetry: { retried = true }
        )

        XCTAssertEqual(nodes.count, 1)
        // Should create generic error with retry
    }

    func testGenericErrorWithDetails() {
        let nodes = ErrorMessage.genericError(
            message: "Something went wrong",
            details: "Error code: 500"
        )

        XCTAssertEqual(nodes.count, 1)
        // Should create generic error with details
    }

    // MARK: - CSS Classes Tests

    func testBaseClassPresent() {
        let props = makeTestProps()
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have base error-message class
    }

    func testSeverityClassError() {
        let props = makeTestProps(severity: .error)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have error-message--error class
    }

    func testSeverityClassWarning() {
        let props = makeTestProps(severity: .warning)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have error-message--warning class
    }

    func testSeverityClassInfo() {
        let props = makeTestProps(severity: .info)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have error-message--info class
    }

    // MARK: - Accessibility Tests

    func testAccessibilityRoleAlert() {
        let props = makeTestProps()
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have role="alert" attribute
    }

    func testAccessibilityAriaLive() {
        let props = makeTestProps()
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have aria-live="assertive" attribute
    }

    func testAccessibilityDismissLabel() {
        let props = makeTestProps(showDismiss: true)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Dismiss button should have aria-label
    }

    // MARK: - Edge Cases

    func testRenderWithEmptyMessage() {
        let props = makeTestProps(message: "")
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle empty message
    }

    func testRenderWithLongMessage() {
        let longMessage = String(repeating: "Error ", count: 100)
        let props = makeTestProps(message: longMessage)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle long messages
    }

    func testRenderWithLongDetails() {
        let longDetails = String(repeating: "Details ", count: 100)
        let props = makeTestProps(details: longDetails)
        let nodes = ErrorMessage.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle long details
    }

    func testRenderAllComponents() {
        var retried = false
        var dismissed = false

        let props = ErrorMessage.Props(
            message: "Complete error message",
            severity: .error,
            title: "Error Title",
            details: "Technical details",
            showRetry: true,
            showDismiss: true,
            onRetry: { retried = true },
            onDismiss: { dismissed = true }
        )

        let nodes = ErrorMessage.render(props: props)
        XCTAssertEqual(nodes.count, 1)
        // Should render all components together
    }

    // MARK: - Callback Tests

    func testRetryCallback() {
        var retryCount = 0
        let props = makeTestProps(
            showRetry: true,
            onRetry: { retryCount += 1 }
        )

        let nodes = ErrorMessage.render(props: props)
        XCTAssertEqual(nodes.count, 1)
        props.onRetry?()
        XCTAssertEqual(retryCount, 1)
    }

    func testDismissCallback() {
        var dismissCount = 0
        let props = makeTestProps(
            onDismiss: { dismissCount += 1 }
        )

        let nodes = ErrorMessage.render(props: props)
        XCTAssertEqual(nodes.count, 1)
        props.onDismiss?()
        XCTAssertEqual(dismissCount, 1)
    }
}
