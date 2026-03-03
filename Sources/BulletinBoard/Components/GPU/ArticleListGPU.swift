import Foundation
import LINKER

/// GPU-enhanced ArticleList component extension.
///
/// Wraps the article list container with subtle GPU shadow for depth.
/// Individual ArticleCards automatically use GPU rendering when enabled.
extension ArticleList {

    /// Renders article list with GPU-accelerated container shadow.
    ///
    /// Provides subtle depth to the entire list container,
    /// distinguishing it from the background.
    ///
    /// # Example
    /// ```swift
    /// let props = ArticleList.Props(articles: articles, ...)
    /// let listNodes = ArticleList.renderGPU(props: props)
    /// ```
    ///
    /// # Performance
    /// - GPU mode: WebGPU shadow on container
    /// - Fallback: CSS box-shadow
    /// - Elevation: 1 (subtle depth for container)
    /// - Note: This wrapper does NOT handle individual card rendering
    ///   Use ArticleCard.renderGPU directly if you need per-card GPU effects
    public static func renderGPU(props: Props) -> [AnyNode] {
        // Check if GPU is enabled for this component
        guard GPUComponentConfig.isEnabled(for: "ArticleList") else {
            GPUComponentConfig.log("ArticleList: GPU disabled, using standard render")
            return render(props: props)
        }

        GPUComponentConfig.log("ArticleList: Rendering with GPU shadow (elevation1)")

        // Get custom shadow style if configured
        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ArticleList") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            // Default: elevation1 for subtle container depth
            shadowStyle = .elevation1
        }

        // Render original list (standard ArticleCards)
        let listContent = render(props: props)

        // Wrap container with GPU shadow
        return ShadowView(style: shadowStyle) {
            return listContent
        }
    }

    /// Renders virtual scrolling list with GPU-enhanced container.
    public static func renderVirtualGPU(
        props: Props,
        scrollTop: Int,
        config: VirtualScrollConfig
    ) -> [AnyNode] {
        // Check if GPU is enabled
        guard GPUComponentConfig.isEnabled(for: "ArticleList") else {
            GPUComponentConfig.log("ArticleList: GPU disabled for virtual scroll, using standard render")
            return renderVirtual(props: props, scrollTop: scrollTop, config: config)
        }

        GPUComponentConfig.log("ArticleList: Rendering virtual scroll with GPU shadow (elevation1)")

        // Get custom shadow style if configured
        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ArticleList") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            shadowStyle = .elevation1
        }

        // Render original virtual list
        let listContent = renderVirtual(props: props, scrollTop: scrollTop, config: config)

        // Wrap container with GPU shadow
        return ShadowView(style: shadowStyle) {
            return listContent
        }
    }
}
