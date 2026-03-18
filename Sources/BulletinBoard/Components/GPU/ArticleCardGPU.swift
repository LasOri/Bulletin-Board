import Foundation
import LINKER

extension ArticleCard {

    public static func renderGPU(props: Props) -> [AnyNode] {
        guard GPUComponentConfig.isEnabled(for: "ArticleCard") else {
            GPUComponentConfig.log("ArticleCard: GPU disabled, using standard render")
            return render(props: props)
        }

        GPUComponentConfig.log("ArticleCard: Rendering with GPU shadow (elevation2)")

        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ArticleCard") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            shadowStyle = .elevation2
        }

        let cardContent = render(props: props)

        return ShadowView(id: "article-shadow-\(props.article.id)", style: shadowStyle) {
            return cardContent
        }
    }
}

