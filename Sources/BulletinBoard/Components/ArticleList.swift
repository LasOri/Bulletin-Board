import Foundation
import LINKER

/// Article list component with virtual scrolling support.
///
/// Efficiently renders large lists of articles by only rendering visible items.
/// Provides empty states and loading indicators.
public struct ArticleList {

    // MARK: - Props

    public struct Props {
        public let articles: [Article]
        public let isLoading: Bool
        public let emptyMessage: String
        public let onToggleFavorite: (String) -> Void
        public let onMarkAsRead: (String) -> Void
        public let onArticleClick: (String) -> Void

        public init(
            articles: [Article],
            isLoading: Bool = false,
            emptyMessage: String = "No articles to display",
            onToggleFavorite: @escaping (String) -> Void,
            onMarkAsRead: @escaping (String) -> Void,
            onArticleClick: @escaping (String) -> Void
        ) {
            self.articles = articles
            self.isLoading = isLoading
            self.emptyMessage = emptyMessage
            self.onToggleFavorite = onToggleFavorite
            self.onMarkAsRead = onMarkAsRead
            self.onArticleClick = onArticleClick
        }
    }

    // MARK: - Render

    public static func render(props: Props) -> [AnyNode] {
        let container = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "article-list")],
            children: renderContent(props: props)
        )

        return [AnyNode(container)]
    }

    // MARK: - Private Helpers

    private static func renderContent(props: Props) -> [AnyNode] {
        if props.isLoading {
            return [AnyNode(renderLoadingState())]
        }

        if props.articles.isEmpty {
            return [AnyNode(renderEmptyState(message: props.emptyMessage))]
        }

        return renderArticles(props: props)
    }

    private static func renderLoadingState() -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "article-list__loading")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "loading-spinner")],
                    children: []
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "p",
                    children: [AnyNode(Text("Loading articles..."))]
                ))
            ]
        )
    }

    private static func renderEmptyState(message: String) -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "article-list__empty")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "p",
                    attributes: [Attribute(name: "class", value: "article-list__empty-message")],
                    children: [AnyNode(Text(message))]
                ))
            ]
        )
    }

    private static func renderArticles(props: Props) -> [AnyNode] {
        var children: [AnyNode] = []

        // Add article count header
        children.append(AnyNode(renderListHeader(count: props.articles.count)))

        // Render each article card
        for article in props.articles {
            let cardProps = ArticleCard.Props(
                article: article,
                onToggleFavorite: props.onToggleFavorite,
                onMarkAsRead: props.onMarkAsRead,
                onClick: props.onArticleClick
            )

            let cardNodes = ArticleCard.render(props: cardProps)
            children.append(contentsOf: cardNodes)
        }

        return children
    }

    private static func renderListHeader(count: Int) -> Element<AnyHTMLContext> {
        let countText = count == 1 ? "1 article" : "\(count) articles"

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "article-list__header")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "span",
                    attributes: [Attribute(name: "class", value: "article-list__count")],
                    children: [AnyNode(Text(countText))]
                ))
            ]
        )
    }
}

// MARK: - Virtual Scrolling Support

extension ArticleList {

    /// Configuration for virtual scrolling
    public struct VirtualScrollConfig {
        public let itemHeight: Int
        public let bufferSize: Int
        public let containerHeight: Int

        public init(
            itemHeight: Int = 300,
            bufferSize: Int = 5,
            containerHeight: Int = 800
        ) {
            self.itemHeight = itemHeight
            self.bufferSize = bufferSize
            self.containerHeight = containerHeight
        }
    }

    /// Calculate visible range for virtual scrolling
    public static func calculateVisibleRange(
        scrollTop: Int,
        config: VirtualScrollConfig,
        totalItems: Int
    ) -> Range<Int> {
        let startIndex = max(0, (scrollTop / config.itemHeight) - config.bufferSize)
        let endIndex = min(
            totalItems,
            ((scrollTop + config.containerHeight) / config.itemHeight) + config.bufferSize
        )

        return startIndex..<endIndex
    }

    /// Render only visible articles with virtual scrolling
    public static func renderVirtual(
        props: Props,
        scrollTop: Int,
        config: VirtualScrollConfig
    ) -> [AnyNode] {
        if props.isLoading || props.articles.isEmpty {
            return render(props: props)
        }

        let totalItems = props.articles.count
        let visibleRange = calculateVisibleRange(
            scrollTop: scrollTop,
            config: config,
            totalItems: totalItems
        )

        // Calculate total height and offset
        let totalHeight = totalItems * config.itemHeight
        let offsetTop = visibleRange.lowerBound * config.itemHeight

        // Create spacer elements for virtual scrolling
        let topSpacer = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "article-list__spacer"),
                Attribute(name: "style", value: "height: \(offsetTop)px")
            ],
            children: []
        )

        let bottomSpacerHeight = totalHeight - (visibleRange.upperBound * config.itemHeight)
        let bottomSpacer = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "article-list__spacer"),
                Attribute(name: "style", value: "height: \(bottomSpacerHeight)px")
            ],
            children: []
        )

        // Render visible articles
        var children: [AnyNode] = [AnyNode(topSpacer)]

        children.append(AnyNode(renderListHeader(count: totalItems)))

        for index in visibleRange {
            guard index < props.articles.count else { break }
            let article = props.articles[index]

            let cardProps = ArticleCard.Props(
                article: article,
                onToggleFavorite: props.onToggleFavorite,
                onMarkAsRead: props.onMarkAsRead,
                onClick: props.onArticleClick
            )

            let cardNodes = ArticleCard.render(props: cardProps)
            children.append(contentsOf: cardNodes)
        }

        children.append(AnyNode(bottomSpacer))

        let container = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "article-list article-list--virtual"),
                Attribute(name: "data-total-items", value: String(totalItems)),
                Attribute(name: "data-visible-start", value: String(visibleRange.lowerBound)),
                Attribute(name: "data-visible-end", value: String(visibleRange.upperBound))
            ],
            children: children
        )

        return [AnyNode(container)]
    }
}
