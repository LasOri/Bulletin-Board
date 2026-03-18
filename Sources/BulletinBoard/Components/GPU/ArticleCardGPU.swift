import Foundation
import LINKER

extension ArticleCard {

    public static func renderGPU(props: Props) -> [AnyNode] {
        guard GPUComponentConfig.isEnabled(for: "ArticleCard") else {
            GPUComponentConfig.log("ArticleCard: GPU disabled, using standard render")
            return render(props: props)
        }

        let article = props.article
        let cardContent = render(props: props)

        if let dc = article.dominantColor {
            let tintedStyle = BlurStyle.tinted(
                r: dc.r,
                g: dc.g,
                b: dc.b,
                a: 0.15,
                radius: 6,
                saturation: 1.8
            )

            return ShadowView(
                id: "article-shadow-\(article.id)",
                style: .elevation2,
                mouseReactive: true
            ) {
                return BlurView(
                    id: "article-blur-\(article.id)",
                    style: tintedStyle,
                    intensity: 1.0
                ) {
                    return cardContent
                }
            }
        }

        return ShadowView(
            id: "article-shadow-\(article.id)",
            style: .elevation2,
            mouseReactive: true
        ) {
            return cardContent
        }
    }
}
