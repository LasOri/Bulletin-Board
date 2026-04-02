import LINKER

public enum ViewMode: String, Sendable {
    case list
    case grid
}

public struct CategoryGrid {

    public static func render(
        props: ArticleList.Props,
        scrollTop: Int,
        config: ArticleList.VirtualScrollConfig
    ) -> [AnyNode] {
        let articles = props.articles
        guard !articles.isEmpty else {
            return ArticleList.render(props: props)
        }

        let grouped = groupByCategory(articles: articles)

        var columns: [AnyNode] = []

        for (category, categoryArticles) in grouped {
            let header = Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "category-column__header")],
                children: [
                    AnyNode(Element<AnyHTMLContext>(
                        tag: "span",
                        attributes: [Attribute(name: "class", value: "category-column__name")],
                        children: [AnyNode(Text(category.rawValue))]
                    )),
                    AnyNode(Element<AnyHTMLContext>(
                        tag: "span",
                        attributes: [
                            Attribute(name: "class", value: "category-column__count"),
                            Attribute(name: "style", value: "background-color: \(category.color)")
                        ],
                        children: [AnyNode(Text(String(categoryArticles.count)))]
                    ))
                ]
            )

            var cardNodes: [AnyNode] = []
            for article in categoryArticles {
                let cardProps = ArticleCard.Props(
                    article: article,
                    onToggleFavorite: props.onToggleFavorite,
                    onMarkAsRead: props.onMarkAsRead,
                    onClick: props.onArticleClick
                )
                cardNodes.append(contentsOf: CategoryGridCard.renderGPU(props: cardProps))
            }

            let column = Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "category-column")],
                children: [AnyNode(header)] + cardNodes
            )
            columns.append(AnyNode(column))
        }

        let grid = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "category-grid")],
            children: columns
        )

        return [AnyNode(grid)]
    }

    public static func groupByCategory(articles: [Article]) -> [(ArticleCategory, [Article])] {
        var groups: [ArticleCategory: [Article]] = [:]
        var uncategorized: [Article] = []

        for article in articles {
            if let cat = article.autoCategory {
                groups[cat, default: []].append(article)
            } else {
                uncategorized.append(article)
            }
        }

        var result: [(ArticleCategory, [Article])] = []
        for category in ArticleCategory.allCases {
            if let group = groups[category], !group.isEmpty {
                result.append((category, group))
            }
        }
        if !uncategorized.isEmpty {
            result.append((.other, uncategorized))
        }

        return result
    }
}
