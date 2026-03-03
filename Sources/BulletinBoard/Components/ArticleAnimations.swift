import Foundation
import LINKER

/// Animation configurations for article components.
///
/// Provides spring physics and transition configs for smooth,
/// natural animations throughout the article UI.
public struct ArticleAnimations {

    // MARK: - Spring Configs

    /// Spring config for article card expansion
    public static let cardExpand = SpringConfig.stiff

    /// Spring config for article card collapse
    public static let cardCollapse = SpringConfig.stiff

    /// Spring config for smooth scrolling
    public static let smoothScroll = SpringConfig.gentle

    /// Spring config for favorite button
    public static let favoriteToggle = SpringConfig.wobbly

    /// Spring config for list item entry
    public static let listEntry = SpringConfig(tension: 190, friction: 22)

    // MARK: - Transition Configs

    /// Fade transition for article cards
    public static let cardFade = TransitionConfig.fade

    /// Slide transition for article list items
    public static let listSlide = TransitionConfig(
        type: .slideUp,
        durationMs: 250,
        timingFunction: "ease-out"
    )

    /// Scale transition for images
    public static let imageScale = TransitionConfig(
        type: .scale,
        durationMs: 300,
        timingFunction: "ease-in-out"
    )

    /// Fast fade for loading states
    public static let loadingFade = TransitionConfig.fast

    // MARK: - Animation Helpers

    /// Creates an animated signal for article card height
    /// - Parameter initialHeight: Initial height in pixels
    /// - Returns: AnimatedSignal for smooth height transitions
    public static func createHeightSignal(initialHeight: Double = 0) -> AnimatedSignal {
        AnimatedSignal(initialValue: initialHeight, config: cardExpand)
    }

    /// Creates an animated signal for opacity
    /// - Parameter initialOpacity: Initial opacity (0.0-1.0)
    /// - Returns: AnimatedSignal for fade animations
    public static func createOpacitySignal(initialOpacity: Double = 1.0) -> AnimatedSignal {
        AnimatedSignal(initialValue: initialOpacity, config: cardFade.toSpringConfig())
    }

    /// Creates an animated signal for scale
    /// - Parameter initialScale: Initial scale (default 1.0)
    /// - Returns: AnimatedSignal for scale animations
    public static func createScaleSignal(initialScale: Double = 1.0) -> AnimatedSignal {
        AnimatedSignal(initialValue: initialScale, config: favoriteToggle)
    }

    /// Creates an animated signal for translation
    /// - Parameter initialOffset: Initial offset in pixels
    /// - Returns: AnimatedSignal for slide animations
    public static func createTranslationSignal(initialOffset: Double = 0) -> AnimatedSignal {
        AnimatedSignal(initialValue: initialOffset, config: listEntry)
    }

    // MARK: - CSS Style Generators

    /// Generates CSS style string for animated height
    /// - Parameter height: Height in pixels
    /// - Returns: CSS style string
    public static func heightStyle(_ height: Double) -> String {
        "height: \(height)px; overflow: hidden;"
    }

    /// Generates CSS style string for animated opacity
    /// - Parameter opacity: Opacity value (0.0-1.0)
    /// - Returns: CSS style string
    public static func opacityStyle(_ opacity: Double) -> String {
        "opacity: \(opacity);"
    }

    /// Generates CSS style string for animated scale
    /// - Parameter scale: Scale value
    /// - Returns: CSS style string
    public static func scaleStyle(_ scale: Double) -> String {
        "transform: scale(\(scale)); will-change: transform;"
    }

    /// Generates CSS style string for animated translation
    /// - Parameter offset: Translation offset in pixels
    /// - Parameter axis: Translation axis ("x" or "y")
    /// - Returns: CSS style string
    public static func translateStyle(_ offset: Double, axis: Character = "y") -> String {
        let transform = axis == "x"
            ? "translateX(\(offset)px)"
            : "translateY(\(offset)px)"
        return "transform: \(transform); will-change: transform;"
    }

    /// Generates combined CSS style for card expansion
    /// - Parameters:
    ///   - height: Height in pixels
    ///   - opacity: Opacity value
    /// - Returns: CSS style string
    public static func expandStyle(height: Double, opacity: Double) -> String {
        "height: \(height)px; opacity: \(opacity); overflow: hidden; will-change: height, opacity;"
    }
}

// MARK: - TransitionConfig Extensions

extension TransitionConfig {
    /// Converts transition config to equivalent spring config
    /// (approximate conversion based on duration and timing)
    func toSpringConfig() -> SpringConfig {
        switch durationMs {
        case 0..<200:
            return .stiff
        case 200..<400:
            return SpringConfig() // default
        case 400..<600:
            return .gentle
        default:
            return .slow
        }
    }
}

// MARK: - Easing Functions

/// Easing functions for custom animations
public enum EasingFunction {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case easeInQuad
    case easeOutQuad
    case easeInOutQuad
    case easeInCubic
    case easeOutCubic
    case easeInOutCubic

    /// Applies easing to a progress value (0.0-1.0)
    /// - Parameter t: Progress (0.0-1.0)
    /// - Returns: Eased progress
    public func apply(_ t: Double) -> Double {
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t
        case .easeOut:
            return t * (2.0 - t)
        case .easeInOut:
            return t < 0.5 ? 2.0 * t * t : -1.0 + (4.0 - 2.0 * t) * t
        case .easeInQuad:
            return t * t
        case .easeOutQuad:
            return t * (2.0 - t)
        case .easeInOutQuad:
            return t < 0.5 ? 2.0 * t * t : -1.0 + (4.0 - 2.0 * t) * t
        case .easeInCubic:
            return t * t * t
        case .easeOutCubic:
            let t1 = t - 1.0
            return t1 * t1 * t1 + 1.0
        case .easeInOutCubic:
            return t < 0.5
                ? 4.0 * t * t * t
                : (t - 1.0) * (2.0 * t - 2.0) * (2.0 * t - 2.0) + 1.0
        }
    }
}

// MARK: - Animation State

/// Tracks animation state for article components
public final class ArticleAnimationState {
    /// Is article expanded
    public var isExpanded: Bool = false

    /// Current height signal
    public let heightSignal: AnimatedSignal

    /// Current opacity signal
    public let opacitySignal: AnimatedSignal

    /// Collapsed height (e.g., card preview height)
    public var collapsedHeight: Double = 200.0

    /// Expanded height (e.g., full article height)
    public var expandedHeight: Double = 600.0

    public init() {
        // Initialize signals with default heights
        // Note: Must use literal values here, not self.collapsedHeight
        // because Swift doesn't allow accessing instance properties before all stored properties are initialized
        self.heightSignal = ArticleAnimations.createHeightSignal(initialHeight: 200.0)
        self.opacitySignal = ArticleAnimations.createOpacitySignal()
    }

    /// Toggles expansion state with animation
    public func toggle() {
        isExpanded.toggle()
        let targetHeight = isExpanded ? expandedHeight : collapsedHeight
        heightSignal.set(targetHeight)
    }

    /// Expands the article
    public func expand() {
        guard !isExpanded else { return }
        isExpanded = true
        heightSignal.set(expandedHeight)
    }

    /// Collapses the article
    public func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        heightSignal.set(collapsedHeight)
    }

    /// Fades in the article
    public func fadeIn() {
        opacitySignal.set(1.0)
    }

    /// Fades out the article
    public func fadeOut() {
        opacitySignal.set(0.0)
    }
}
