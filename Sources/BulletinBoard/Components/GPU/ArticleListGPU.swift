import Foundation
import LINKER

extension ArticleList {

    public static func renderGPU(props: Props) -> [AnyNode] {
        guard GPUComponentConfig.isEnabled(for: "ArticleList") else {
            GPUComponentConfig.log("ArticleList: GPU disabled, using standard render")
            return render(props: props)
        }

        GPUComponentConfig.log("ArticleList: Rendering with GPU shadow (elevation1)")

        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ArticleList") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            shadowStyle = .elevation1
        }

        let listContent = render(props: props)

        return ShadowView(id: "article-list-shadow", style: shadowStyle) {
            return listContent
        }
    }

    public static func renderVirtualGPU(
        props: Props,
        scrollTop: Int,
        config: VirtualScrollConfig
    ) -> [AnyNode] {
        guard GPUComponentConfig.isEnabled(for: "ArticleList") else {
            GPUComponentConfig.log("ArticleList: GPU disabled for virtual scroll, using standard render")
            return renderVirtual(props: props, scrollTop: scrollTop, config: config)
        }

        GPUComponentConfig.log("ArticleList: Rendering virtual scroll with GPU shadow (elevation1)")

        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ArticleList") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            shadowStyle = .elevation1
        }

        let listContent = renderVirtual(props: props, scrollTop: scrollTop, config: config)

        return ShadowView(id: "article-list-virtual-shadow", style: shadowStyle) {
            return listContent
        }
    }
}

