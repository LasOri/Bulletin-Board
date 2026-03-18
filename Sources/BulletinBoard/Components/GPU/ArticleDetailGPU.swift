import Foundation
import LINKER

extension ArticleDetailView {

    public static func renderGPU(props: Props) -> [AnyNode] {
        guard GPUComponentConfig.isEnabled(for: "ArticleDetail") else {
            GPUComponentConfig.log("ArticleDetail: GPU disabled, using standard render")
            return render(props: props)
        }

        GPUComponentConfig.log("ArticleDetail: Rendering with GPU shadow (elevation8)")

        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ArticleDetail") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            shadowStyle = .elevation8
        }

        let article = props.article
        let relatedArticles = props.relatedArticles

        let backdrop = BlurView(id: "article-detail-backdrop", style: .frostedGlass, intensity: 1.0) {
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

