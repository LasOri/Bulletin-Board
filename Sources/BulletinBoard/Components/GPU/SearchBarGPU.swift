import Foundation
import LINKER

/// GPU-enhanced SearchBar component extension.
///
/// Adds dynamic GPU shadow that appears when search is active,
/// providing visual feedback for the interaction state.
extension SearchBar {

    /// Renders search bar with dynamic GPU shadow based on active state.
    ///
    /// Shadow only appears when the search query is not empty,
    /// providing subtle visual feedback that the search is active.
    ///
    /// # Example
    /// ```swift
    /// let props = SearchBar.Props(query: query, ...)
    /// let searchNodes = SearchBar.renderGPU(props: props)
    /// ```
    ///
    /// # Performance
    /// - GPU mode: WebGPU shadow when active
    /// - Fallback: CSS box-shadow when active
    /// - Elevation: 4 (raised element)
    /// - Dynamic: Only shows shadow when query is not empty
    public static func renderGPU(props: Props) -> [AnyNode] {
        // Check if GPU is enabled for this component
        guard GPUComponentConfig.isEnabled(for: "SearchBar") else {
            GPUComponentConfig.log("SearchBar: GPU disabled, using standard render")
            return render(props: props)
        }

        // Render original search bar
        let searchBarContent = render(props: props)

        // Only add shadow when search is active (query not empty)
        if !props.query.isEmpty {
            GPUComponentConfig.log("SearchBar: Rendering with GPU shadow (elevation4, active state)")

            // Get custom shadow style if configured
            let shadowStyle: ShadowStyle
            if let custom = GPUComponentConfig.shadowStyle(for: "SearchBar") {
                shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
            } else {
                // Default: elevation4 for active search state
                shadowStyle = .elevation4
            }

            // Wrap with GPU shadow
            return ShadowView(id: "search-bar-shadow", style: shadowStyle) {
                return searchBarContent
            }
        } else {
            GPUComponentConfig.log("SearchBar: No GPU shadow (inactive state)")
            return searchBarContent
        }
    }
}
