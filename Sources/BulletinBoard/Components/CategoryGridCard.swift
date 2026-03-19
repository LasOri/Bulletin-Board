import Foundation
import LINKER

public struct CategoryGridCard {

    public static func render(props: ArticleCard.Props) -> [AnyNode] {
        let article = props.article

        var attrs: [Attribute] = [
            Attribute(name: "class", value: cardClasses(article: article)),
            Attribute(name: "data-article-id", value: article.id),
            Attribute(name: "data-action", value: "article-click")
        ]

        #if canImport(JavaScriptKit) && arch(wasm32)
        if let dc = article.dominantColor {
            let comp = ColorExtractor.mutedComplement(of: (r: dc.r, g: dc.g, b: dc.b))
            let r = Int(comp.r * 255)
            let g = Int(comp.g * 255)
            let b = Int(comp.b * 255)
            attrs.append(Attribute(name: "style", value: "color: rgb(\(r), \(g), \(b))"))
        }
        #endif

        var children: [AnyNode] = []

        children.append(AnyNode(Element<AnyHTMLContext>(
            tag: "h4",
            attributes: [Attribute(name: "class", value: "grid-card__title")],
            children: [AnyNode(Text(article.title))]
        )))

        if let displayText = article.displayContent.isEmpty ? nil : article.displayContent {
            let truncated: String
            if displayText.count > 100 {
                let prefix = displayText.prefix(100)
                if let lastSpace = prefix.lastIndex(of: " ") {
                    truncated = String(prefix[prefix.startIndex..<lastSpace]) + "…"
                } else {
                    truncated = String(prefix) + "…"
                }
            } else {
                truncated = displayText
            }
            children.append(AnyNode(Element<AnyHTMLContext>(
                tag: "p",
                attributes: [Attribute(name: "class", value: "grid-card__description")],
                children: [AnyNode(Text(truncated))]
            )))
        }

        if !article.keywords.isEmpty {
            let keywordEls = article.keywords.prefix(3).map { keyword in
                AnyNode(Element<AnyHTMLContext>(
                    tag: "span",
                    attributes: [Attribute(name: "class", value: "grid-card__keyword")],
                    children: [AnyNode(Text(keyword))]
                ))
            }
            children.append(AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "grid-card__keywords")],
                children: keywordEls
            )))
        }

        var metaParts: [String] = []
        if let date = article.publishedAt {
            metaParts.append(ArticleCard.formatRelativeDate(date))
        }
        if !metaParts.isEmpty {
            children.append(AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "grid-card__meta")],
                children: [AnyNode(Text(metaParts.joined(separator: " • ")))]
            )))
        }

        var actions: [AnyNode] = []
        let favIcon = article.isFavorite ? "★" : "☆"
        actions.append(AnyNode(Element<AnyHTMLContext>(
            tag: "button",
            attributes: [
                Attribute(name: "class", value: "grid-card__action"),
                Attribute(name: "data-article-id", value: article.id),
                Attribute(name: "data-action", value: "toggle-favorite"),
                Attribute(name: "aria-label", value: article.isFavorite ? "Unfavorite" : "Favorite")
            ],
            children: [AnyNode(Text(favIcon))]
        )))
        actions.append(AnyNode(Element<AnyHTMLContext>(
            tag: "span",
            attributes: [Attribute(name: "class", value: "grid-card__read-indicator")],
            children: [AnyNode(Text(article.isRead ? "✓" : "•"))]
        )))
        children.append(AnyNode(Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "grid-card__actions")],
            children: actions
        )))

        let card = Element<AnyHTMLContext>(
            tag: "article",
            attributes: attrs,
            children: children
        )

        return [AnyNode(card)]
    }

    public static func renderGPU(props: ArticleCard.Props) -> [AnyNode] {
        guard GPUComponentConfig.isEnabled(for: "CategoryGridCard") else {
            return render(props: props)
        }

        let article = props.article
        let cardContent = render(props: props)

        if let dc = article.dominantColor {
            let tintedStyle = BlurStyle.tinted(
                r: dc.r,
                g: dc.g,
                b: dc.b,
                a: 0.35,
                radius: 6,
                saturation: 1.8
            )

            return ShadowView(
                id: "grid-shadow-\(article.id)",
                style: .elevation1,
                mouseReactive: false
            ) {
                return BlurView(
                    id: "grid-blur-\(article.id)",
                    style: tintedStyle,
                    intensity: 1.0
                ) {
                    return cardContent
                }
            }
        }

        return ShadowView(
            id: "grid-shadow-\(article.id)",
            style: .elevation1,
            mouseReactive: false
        ) {
            return cardContent
        }
    }

    private static func cardClasses(article: Article) -> String {
        var classes = ["grid-card"]
        if article.isRead { classes.append("grid-card--read") }
        if article.isFavorite { classes.append("grid-card--favorite") }
        if article.dominantColor != nil { classes.append("grid-card--tinted") }
        if article.id == appStore.getState().articles.selectedId {
            classes.append("grid-card--selected")
        }
        return classes.joined(separator: " ")
    }
}
