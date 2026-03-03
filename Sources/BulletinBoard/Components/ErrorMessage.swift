import Foundation
import LINKER

/// Error message component for displaying errors with actions.
///
/// Provides a consistent way to display error messages with optional
/// retry actions and dismissal functionality.
public struct ErrorMessage {

    // MARK: - Types

    /// Error severity level
    public enum Severity: String {
        case error = "error"
        case warning = "warning"
        case info = "info"
    }

    // MARK: - Props

    public struct Props {
        public let message: String
        public let severity: Severity
        public let title: String?
        public let details: String?
        public let showRetry: Bool
        public let showDismiss: Bool
        public let onRetry: (() -> Void)?
        public let onDismiss: (() -> Void)?

        public init(
            message: String,
            severity: Severity = .error,
            title: String? = nil,
            details: String? = nil,
            showRetry: Bool = false,
            showDismiss: Bool = true,
            onRetry: (() -> Void)? = nil,
            onDismiss: (() -> Void)? = nil
        ) {
            self.message = message
            self.severity = severity
            self.title = title
            self.details = details
            self.showRetry = showRetry
            self.showDismiss = showDismiss
            self.onRetry = onRetry
            self.onDismiss = onDismiss
        }
    }

    // MARK: - Render

    public static func render(props: Props) -> [AnyNode] {
        let container = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: containerClasses(severity: props.severity)),
                Attribute(name: "role", value: "alert"),
                Attribute(name: "aria-live", value: "assertive")
            ],
            children: [
                AnyNode(renderIcon(severity: props.severity)),
                AnyNode(renderContent(props: props)),
                AnyNode(renderActions(props: props))
            ]
        )

        return [AnyNode(container)]
    }

    // MARK: - Private Helpers

    private static func containerClasses(severity: Severity) -> String {
        return "error-message error-message--\(severity.rawValue)"
    }

    private static func renderIcon(severity: Severity) -> Element<AnyHTMLContext> {
        let icon = iconForSeverity(severity)

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "error-message__icon"),
                Attribute(name: "aria-hidden", value: "true")
            ],
            children: [AnyNode(Text(icon))]
        )
    }

    private static func iconForSeverity(_ severity: Severity) -> String {
        switch severity {
        case .error: return "⚠️"
        case .warning: return "⚡"
        case .info: return "ℹ️"
        }
    }

    private static func renderContent(props: Props) -> Element<AnyHTMLContext> {
        var children: [AnyNode] = []

        // Title (if provided)
        if let title = props.title {
            let titleElement = Element<AnyHTMLContext>(
                tag: "h3",
                attributes: [Attribute(name: "class", value: "error-message__title")],
                children: [AnyNode(Text(title))]
            )
            children.append(AnyNode(titleElement))
        }

        // Main message
        let messageElement = Element<AnyHTMLContext>(
            tag: "p",
            attributes: [Attribute(name: "class", value: "error-message__message")],
            children: [AnyNode(Text(props.message))]
        )
        children.append(AnyNode(messageElement))

        // Details (if provided)
        if let details = props.details {
            let detailsElement = Element<AnyHTMLContext>(
                tag: "p",
                attributes: [Attribute(name: "class", value: "error-message__details")],
                children: [AnyNode(Text(details))]
            )
            children.append(AnyNode(detailsElement))
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "error-message__content")],
            children: children
        )
    }

    private static func renderActions(props: Props) -> Element<AnyHTMLContext> {
        var children: [AnyNode] = []

        // Retry button
        if props.showRetry {
            let retryButton = Element<AnyHTMLContext>(
                tag: "button",
                attributes: [
                    Attribute(name: "type", value: "button"),
                    Attribute(name: "class", value: "error-message__action error-message__retry"),
                    Attribute(name: "data-action", value: "retry")
                ],
                children: [AnyNode(Text("Retry"))]
            )
            children.append(AnyNode(retryButton))
        }

        // Dismiss button
        if props.showDismiss {
            let dismissButton = Element<AnyHTMLContext>(
                tag: "button",
                attributes: [
                    Attribute(name: "type", value: "button"),
                    Attribute(name: "class", value: "error-message__action error-message__dismiss"),
                    Attribute(name: "aria-label", value: "Dismiss error"),
                    Attribute(name: "data-action", value: "dismiss")
                ],
                children: [AnyNode(Text("✕"))]
            )
            children.append(AnyNode(dismissButton))
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "error-message__actions")],
            children: children
        )
    }
}

// MARK: - Convenience Constructors

extension ErrorMessage {

    /// Create an error message (red, critical)
    public static func error(
        message: String,
        title: String? = nil,
        details: String? = nil,
        showRetry: Bool = false,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> [AnyNode] {
        render(props: Props(
            message: message,
            severity: .error,
            title: title,
            details: details,
            showRetry: showRetry,
            onRetry: onRetry,
            onDismiss: onDismiss
        ))
    }

    /// Create a warning message (yellow/amber)
    public static func warning(
        message: String,
        title: String? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> [AnyNode] {
        render(props: Props(
            message: message,
            severity: .warning,
            title: title,
            onDismiss: onDismiss
        ))
    }

    /// Create an info message (blue)
    public static func info(
        message: String,
        title: String? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> [AnyNode] {
        render(props: Props(
            message: message,
            severity: .info,
            title: title,
            onDismiss: onDismiss
        ))
    }
}

// MARK: - Common Error Messages

extension ErrorMessage {

    /// Network error with retry
    public static func networkError(
        message: String = "Failed to load data. Please check your connection.",
        onRetry: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil
    ) -> [AnyNode] {
        error(
            message: message,
            title: "Network Error",
            showRetry: true,
            onRetry: onRetry,
            onDismiss: onDismiss
        )
    }

    /// Not found error
    public static func notFound(
        message: String = "The requested item could not be found.",
        onDismiss: (() -> Void)? = nil
    ) -> [AnyNode] {
        error(
            message: message,
            title: "Not Found",
            onDismiss: onDismiss
        )
    }

    /// Permission denied error
    public static func permissionDenied(
        message: String = "You don't have permission to perform this action.",
        onDismiss: (() -> Void)? = nil
    ) -> [AnyNode] {
        error(
            message: message,
            title: "Permission Denied",
            onDismiss: onDismiss
        )
    }

    /// Validation error
    public static func validationError(
        message: String,
        details: String? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> [AnyNode] {
        error(
            message: message,
            title: "Validation Error",
            details: details,
            onDismiss: onDismiss
        )
    }

    /// Generic error with technical details
    public static func genericError(
        message: String = "An unexpected error occurred.",
        details: String? = nil,
        showRetry: Bool = true,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> [AnyNode] {
        error(
            message: message,
            title: "Error",
            details: details,
            showRetry: showRetry,
            onRetry: onRetry,
            onDismiss: onDismiss
        )
    }
}
