import Foundation
import LINKER

/// GPU-enhanced ArticleCard component extension.
///
/// Wraps the original ArticleCard with GPU-accelerated shadow for visual depth.
/// Falls back to original rendering when GPU is disabled.
extension ArticleCard {

    /// Renders article card with GPU-accelerated shadow (elevation2).
    ///
    /// This provides subtle card elevation using WebGPU shadows or CSS fallback.
    /// The shadow gives visual depth without being intrusive.
    ///
    /// # Example
    /// ```swift
    /// let props = ArticleCard.Props(article: article, ...)
    /// let cardNodes = ArticleCard.renderGPU(props: props)
    /// ```
    ///
    /// # Performance
    /// - GPU mode: WebGPU canvas-based shadow
    /// - Fallback: CSS box-shadow
    /// - Elevation: 2 (subtle card depth)
    /// - Intensity: 0.25 (light shadow)
    public static func renderGPU(props: Props) -> [AnyNode] {
        // Check if GPU is enabled for this component
        guard GPUComponentConfig.isEnabled(for: "ArticleCard") else {
            GPUComponentConfig.log("ArticleCard: GPU disabled, using standard render")
            return render(props: props)
        }

        GPUComponentConfig.log("ArticleCard: Rendering with GPU shadow (elevation2)")

        // Get custom shadow style if configured
        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ArticleCard") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            // Default: elevation2 for subtle card depth
            shadowStyle = .elevation2
        }

        // Render original card content
        let cardContent = render(props: props)

        // Wrap with GPU shadow
        return ShadowView(id: "article-shadow-\(props.article.id)", style: shadowStyle) {
            return cardContent
        }
    }
}
