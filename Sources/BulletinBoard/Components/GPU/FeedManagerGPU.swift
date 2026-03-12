import Foundation
import LINKER

/// GPU-enhanced FeedManager component extension.
///
/// Wraps the original FeedManager modal with iOS-style effects:
/// - BlurView for frosted glass background
/// - ShadowView for elevated modal shadow
///
/// Creates an iOS-quality modal experience with GPU acceleration.
extension FeedManager {

    /// Renders feed manager modal with GPU-accelerated blur and shadow.
    ///
    /// Combines two GPU effects for maximum visual impact:
    /// 1. Frosted glass blur background (iOS glassmorphism)
    /// 2. High elevation shadow (modal prominence)
    ///
    /// # Example
    /// ```swift
    /// let props = FeedManager.Props(feeds: feeds, ...)
    /// let modalNodes = FeedManager.renderGPU(props: props)
    /// ```
    ///
    /// # Performance
    /// - GPU mode: WebGPU blur + shadow
    /// - Fallback: CSS backdrop-filter + box-shadow
    /// - Blur: frostedGlass style (radius 12, saturation 220%)
    /// - Shadow: elevation24 (modal depth)
    ///
    /// # Visual Effect
    /// The combination creates an iOS-like modal that:
    /// - Blurs the content behind it
    /// - Floats above with prominent shadow
    /// - Maintains 60 FPS performance
    public static func renderGPU(props: Props) -> [AnyNode] {
        // Check if GPU is enabled for this component
        guard GPUComponentConfig.isEnabled(for: "FeedManager") else {
            GPUComponentConfig.log("FeedManager: GPU disabled, using standard render")
            return render(props: props)
        }

        GPUComponentConfig.log("FeedManager: Rendering with GPU blur + shadow (iOS modal)")

        // Get custom styles if configured
        let blurStyle: BlurStyle
        if let custom = GPUComponentConfig.blurStyle(for: "FeedManager") {
            blurStyle = .custom(
                radius: custom.radius,
                saturation: custom.saturation,
                brightness: custom.brightness
            )
        } else {
            // Default: frosted glass for iOS-like background
            blurStyle = .frostedGlass
        }

        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "FeedManager") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            // Default: elevation24 for modal prominence
            shadowStyle = .elevation24
        }

        // Render original modal content
        let modalContent = render(props: props)

        // Layer 1: Blur background (frosted glass effect)
        // Layer 2: Shadow on modal (elevation)
        return BlurView(id: "feed-manager-blur", style: blurStyle, intensity: 0.8, animated: true) {
            return ShadowView(id: "feed-manager-shadow", style: shadowStyle) {
                return modalContent
            }
        }
    }
}
