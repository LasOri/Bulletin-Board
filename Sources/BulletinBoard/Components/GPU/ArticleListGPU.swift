import LINKER

extension ArticleList {

    public static func renderGPU(props: Props) -> [AnyNode] {
        guard GPUComponentConfig.isEnabled(for: "ArticleList") else {
            GPUComponentConfig.log("ArticleList: GPU disabled, using standard render")
            return render(props: props)
        }

        return render(props: props)
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

        return renderVirtual(props: props, scrollTop: scrollTop, config: config)
    }
}
