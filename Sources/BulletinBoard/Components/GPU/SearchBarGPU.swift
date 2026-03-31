import LINKER

extension SearchBar {

    public static func renderGPU(props: Props) -> [AnyNode] {
        guard GPUComponentConfig.isEnabled(for: "SearchBar") else {
            GPUComponentConfig.log("SearchBar: GPU disabled, using standard render")
            return render(props: props)
        }

        let searchBarContent = render(props: props)

        if !props.query.isEmpty {
            GPUComponentConfig.log("SearchBar: Rendering with GPU shadow (elevation4, active state)")

            let shadowStyle: ShadowStyle
            if let custom = GPUComponentConfig.shadowStyle(for: "SearchBar") {
                shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
            } else {
                shadowStyle = .elevation4
            }

            return ShadowView(id: "search-bar-shadow", style: shadowStyle) {
                return searchBarContent
            }
        } else {
            GPUComponentConfig.log("SearchBar: No GPU shadow (inactive state)")
            return searchBarContent
        }
    }
}

