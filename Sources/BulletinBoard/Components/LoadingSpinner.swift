import Foundation
import LINKER

/// Loading spinner component for indicating loading states.
///
/// Provides a visual indicator that content is being loaded,
/// with customizable size and styling options.
public struct LoadingSpinner {

    // MARK: - Types

    /// Spinner size variants
    public enum Size: String {
        case small = "small"
        case medium = "medium"
        case large = "large"

        var dimension: Int {
            switch self {
            case .small: return 20
            case .medium: return 40
            case .large: return 60
            }
        }
    }

    /// Spinner style variants
    public enum Style: String {
        case `default` = "default"
        case primary = "primary"
        case light = "light"
    }

    // MARK: - Props

    public struct Props {
        public let size: Size
        public let style: Style
        public let message: String?
        public let centered: Bool

        public init(
            size: Size = .medium,
            style: Style = .default,
            message: String? = nil,
            centered: Bool = true
        ) {
            self.size = size
            self.style = style
            self.message = message
            self.centered = centered
        }
    }

    // MARK: - Render

    public static func render(props: Props) -> [AnyNode] {
        let container = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: containerClasses(props: props)),
                Attribute(name: "role", value: "status"),
                Attribute(name: "aria-live", value: "polite")
            ],
            children: renderContent(props: props)
        )

        return [AnyNode(container)]
    }

    // MARK: - Private Helpers

    private static func containerClasses(props: Props) -> String {
        var classes = ["loading-spinner"]
        classes.append("loading-spinner--\(props.size.rawValue)")
        classes.append("loading-spinner--\(props.style.rawValue)")
        if props.centered {
            classes.append("loading-spinner--centered")
        }
        return classes.joined(separator: " ")
    }

    private static func renderContent(props: Props) -> [AnyNode] {
        var children: [AnyNode] = []

        // Spinner element
        let spinner = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "loading-spinner__element"),
                Attribute(name: "aria-hidden", value: "true"),
                Attribute(name: "style", value: spinnerStyle(size: props.size))
            ],
            children: renderSpinnerParts()
        )
        children.append(AnyNode(spinner))

        // Optional message
        if let message = props.message {
            let messageElement = Element<AnyHTMLContext>(
                tag: "span",
                attributes: [
                    Attribute(name: "class", value: "loading-spinner__message"),
                    Attribute(name: "aria-label", value: message)
                ],
                children: [AnyNode(Text(message))]
            )
            children.append(AnyNode(messageElement))
        }

        // Accessibility text
        let srText = Element<AnyHTMLContext>(
            tag: "span",
            attributes: [Attribute(name: "class", value: "sr-only")],
            children: [AnyNode(Text(props.message ?? "Loading..."))]
        )
        children.append(AnyNode(srText))

        return children
    }

    private static func spinnerStyle(size: Size) -> String {
        let dimension = size.dimension
        return "width: \(dimension)px; height: \(dimension)px;"
    }

    private static func renderSpinnerParts() -> [AnyNode] {
        // Create 8 spinner bars for animation
        return (1...8).map { i in
            AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [
                    Attribute(name: "class", value: "loading-spinner__bar"),
                    Attribute(name: "data-bar", value: String(i))
                ],
                children: []
            ))
        }
    }
}

// MARK: - Convenience Constructors

extension LoadingSpinner {

    /// Render a small spinner
    public static func small(message: String? = nil) -> [AnyNode] {
        render(props: Props(size: .small, message: message))
    }

    /// Render a medium spinner (default)
    public static func medium(message: String? = nil) -> [AnyNode] {
        render(props: Props(size: .medium, message: message))
    }

    /// Render a large spinner
    public static func large(message: String? = nil) -> [AnyNode] {
        render(props: Props(size: .large, message: message))
    }

    /// Render a light-styled spinner (for dark backgrounds)
    public static func light(size: Size = .medium, message: String? = nil) -> [AnyNode] {
        render(props: Props(size: size, style: .light, message: message))
    }

    /// Render a primary-styled spinner
    public static func primary(size: Size = .medium, message: String? = nil) -> [AnyNode] {
        render(props: Props(size: size, style: .primary, message: message))
    }
}

// MARK: - Inline Spinner

extension LoadingSpinner {

    /// Props for inline spinner (not centered, no message)
    public struct InlineProps {
        public let size: Size
        public let style: Style

        public init(size: Size = .small, style: Style = .default) {
            self.size = size
            self.style = style
        }
    }

    /// Render an inline spinner (for use within text or buttons)
    public static func inline(props: InlineProps) -> [AnyNode] {
        render(props: Props(
            size: props.size,
            style: props.style,
            message: nil,
            centered: false
        ))
    }

    /// Render a small inline spinner
    public static func inlineSmall() -> [AnyNode] {
        inline(props: InlineProps(size: .small))
    }
}
