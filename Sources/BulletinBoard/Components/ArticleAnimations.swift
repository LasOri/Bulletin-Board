import LINKER

public struct ArticleAnimations {

    public static let cardExpand = SpringConfig.stiff

    public static let cardCollapse = SpringConfig.stiff

    public static let smoothScroll = SpringConfig.gentle

    public static let favoriteToggle = SpringConfig.wobbly

    public static let listEntry = SpringConfig(tension: 190, friction: 22)

    public static let cardExpandTransform = SpringConfig(tension: 200, friction: 22)

    public static let cardCollapseTransform = SpringConfig(tension: 250, friction: 28)

    public static let backdropFade = SpringConfig(tension: 280, friction: 40)

    public static let cardFade = TransitionConfig.fade

    public static let listSlide = TransitionConfig(
        type: .slideUp,
        durationMs: 250,
        timingFunction: "ease-out"
    )

    public static let imageScale = TransitionConfig(
        type: .scale,
        durationMs: 300,
        timingFunction: "ease-in-out"
    )

    public static let loadingFade = TransitionConfig.fast

    public static func createHeightSignal(initialHeight: Double = 0) -> AnimatedSignal {
        AnimatedSignal(initialValue: initialHeight, config: cardExpand)
    }

    public static func createOpacitySignal(initialOpacity: Double = 1.0) -> AnimatedSignal {
        AnimatedSignal(initialValue: initialOpacity, config: cardFade.toSpringConfig())
    }

    public static func createScaleSignal(initialScale: Double = 1.0) -> AnimatedSignal {
        AnimatedSignal(initialValue: initialScale, config: favoriteToggle)
    }

    public static func createTranslationSignal(initialOffset: Double = 0) -> AnimatedSignal {
        AnimatedSignal(initialValue: initialOffset, config: listEntry)
    }

    public static func heightStyle(_ height: Double) -> String {
        "height: \(height)px; overflow: hidden;"
    }

    public static func opacityStyle(_ opacity: Double) -> String {
        "opacity: \(opacity);"
    }

    public static func scaleStyle(_ scale: Double) -> String {
        "transform: scale(\(scale)); will-change: transform;"
    }

    public static func translateStyle(_ offset: Double, axis: Character = "y") -> String {
        let transform = axis == "x"
            ? "translateX(\(offset)px)"
            : "translateY(\(offset)px)"
        return "transform: \(transform); will-change: transform;"
    }

    public static func expandStyle(height: Double, opacity: Double) -> String {
        "height: \(height)px; opacity: \(opacity); overflow: hidden; will-change: height, opacity;"
    }
}

extension TransitionConfig {
    func toSpringConfig() -> SpringConfig {
        switch durationMs {
        case 0..<200:
            return .stiff
        case 200..<400:
            return SpringConfig()
        case 400..<600:
            return .gentle
        default:
            return .slow
        }
    }
}

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

public final class ArticleAnimationState {
    public var isExpanded: Bool = false

    public let heightSignal: AnimatedSignal

    public let opacitySignal: AnimatedSignal

    public var collapsedHeight: Double = 200.0

    public var expandedHeight: Double = 600.0

    public init() {
        self.heightSignal = ArticleAnimations.createHeightSignal(initialHeight: 200.0)
        self.opacitySignal = ArticleAnimations.createOpacitySignal()
    }

    public func toggle() {
        isExpanded.toggle()
        let targetHeight = isExpanded ? expandedHeight : collapsedHeight
        heightSignal.set(targetHeight)
    }

    public func expand() {
        guard !isExpanded else { return }
        isExpanded = true
        heightSignal.set(expandedHeight)
    }

    public func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        heightSignal.set(collapsedHeight)
    }

    public func fadeIn() {
        opacitySignal.set(1.0)
    }

    public func fadeOut() {
        opacitySignal.set(0.0)
    }
}

