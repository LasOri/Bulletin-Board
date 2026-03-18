import Foundation
import LINKER

extension ArticleDetailView {

    public static func renderGPU(props: Props) -> [AnyNode] {
        guard GPUComponentConfig.isEnabled(for: "ArticleDetail") else {
            GPUComponentConfig.log("ArticleDetail: GPU disabled, using standard render")
            return render(props: props)
        }

        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ArticleDetail") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            shadowStyle = .elevation8
        }

        let article = props.article
        let relatedArticles = props.relatedArticles

        let blurStyle: BlurStyle
        if let dc = article.dominantColor {
            blurStyle = .tinted(r: dc.r, g: dc.g, b: dc.b, a: 0.22, radius: 12, saturation: 2.2)
        } else {
            blurStyle = .frostedGlass
        }

        let backdrop = BlurView(id: "article-detail-backdrop", style: blurStyle, intensity: 1.0) {
            return [AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [
                    Attribute(name: "class", value: "article-detail-overlay"),
                    Attribute(name: "data-action", value: "collapse-article-overlay")
                ],
                children:
                    ShadowView(id: "article-detail-shadow-\(article.id)", style: shadowStyle) {
                        return [AnyNode(renderContentCard(article: article, relatedArticles: relatedArticles))]
                    }
            ))]
        }

        return backdrop
    }
}
