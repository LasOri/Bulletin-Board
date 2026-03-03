import Foundation
import LINKER

/// Article card component for displaying individual articles.
///
/// Displays article metadata, content preview, and interactive elements
/// (favorite, read status, category badge).
public struct ArticleCard {

    // MARK: - Props

    public struct Props {
        public let article: Article
        public let onToggleFavorite: (String) -> Void
        public let onMarkAsRead: (String) -> Void
        public let onClick: (String) -> Void

        public init(
            article: Article,
            onToggleFavorite: @escaping (String) -> Void,
            onMarkAsRead: @escaping (String) -> Void,
            onClick: @escaping (String) -> Void
        ) {
            self.article = article
            self.onToggleFavorite = onToggleFavorite
            self.onMarkAsRead = onMarkAsRead
            self.onClick = onClick
        }
    }

    // MARK: - Render

    public static func render(props: Props) -> [AnyNode] {
        let article = props.article

        // Build card container
        let card = Element<AnyHTMLContext>(
            tag: "article",
            attributes: [
                Attribute(name: "class", value: cardClasses(article: article)),
                Attribute(name: "data-article-id", value: article.id)
            ],
            children: [
                AnyNode(renderHeader(article: article, props: props)),
                AnyNode(renderContent(article: article)),
                AnyNode(renderFooter(article: article, props: props))
            ]
        )

        return [AnyNode(card)]
    }

    // MARK: - Private Helpers

    private static func cardClasses(article: Article) -> String {
        var classes = ["article-card"]
        if article.isRead {
            classes.append("article-card--read")
        }
        if article.isFavorite {
            classes.append("article-card--favorite")
        }
        return classes.joined(separator: " ")
    }

    private static func renderHeader(article: Article, props: Props) -> Element<AnyHTMLContext> {
        var headerChildren: [AnyNode] = []

        // Category badge
        if let category = article.autoCategory {
            headerChildren.append(AnyNode(renderCategoryBadge(category: category)))
        }

        // Title
        let title = Element<AnyHTMLContext>(
            tag: "h3",
            attributes: [Attribute(name: "class", value: "article-card__title")],
            children: [AnyNode(Text(article.title))]
        )
        headerChildren.append(AnyNode(title))

        // Metadata (author, date, source)
        headerChildren.append(AnyNode(renderMetadata(article: article)))

        return Element<AnyHTMLContext>(
            tag: "header",
            attributes: [Attribute(name: "class", value: "article-card__header")],
            children: headerChildren
        )
    }

    private static func renderCategoryBadge(category: ArticleCategory) -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
            tag: "span",
            attributes: [
                Attribute(name: "class", value: "article-card__category"),
                Attribute(name: "style", value: "background-color: \(category.color)")
            ],
            children: [AnyNode(Text(category.rawValue))]
        )
    }

    private static func renderMetadata(article: Article) -> Element<AnyHTMLContext> {
        var metadataParts: [String] = []

        if let author = article.author {
            metadataParts.append(author)
        }

        if let publishedAt = article.publishedAt {
            metadataParts.append(formatDate(publishedAt))
        }

        let metadata = metadataParts.joined(separator: " • ")

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "article-card__metadata")],
            children: [AnyNode(Text(metadata))]
        )
    }

    private static func renderContent(article: Article) -> Element<AnyHTMLContext> {
        var contentChildren: [AnyNode] = []

        // Enclosure (image preview)
        if let enclosure = article.enclosure, enclosure.type.starts(with: "image/") {
            let img = Element<AnyHTMLContext>(
                tag: "img",
                attributes: [
                    Attribute(name: "src", value: enclosure.url),
                    Attribute(name: "alt", value: article.title),
                    Attribute(name: "class", value: "article-card__image")
                ],
                children: []
            )
            contentChildren.append(AnyNode(img))
        }

        // Description/summary
        if let displayText = article.displayContent.isEmpty ? nil : article.displayContent {
            let description = Element<AnyHTMLContext>(
                tag: "p",
                attributes: [Attribute(name: "class", value: "article-card__description")],
                children: [AnyNode(Text(displayText))]
            )
            contentChildren.append(AnyNode(description))
        }

        // Keywords
        if !article.keywords.isEmpty {
            contentChildren.append(AnyNode(renderKeywords(keywords: article.keywords)))
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "article-card__content")],
            children: contentChildren
        )
    }

    private static func renderKeywords(keywords: [String]) -> Element<AnyHTMLContext> {
        let keywordElements = keywords.map { keyword in
            AnyNode(Element<AnyHTMLContext>(
                tag: "span",
                attributes: [Attribute(name: "class", value: "article-card__keyword")],
                children: [AnyNode(Text(keyword))]
            ))
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "article-card__keywords")],
            children: keywordElements
        )
    }

    private static func renderFooter(article: Article, props: Props) -> Element<AnyHTMLContext> {
        // Favorite button
        let favoriteIcon = article.isFavorite ? "★" : "☆"
        let favoriteButton = Element<AnyHTMLContext>(
            tag: "button",
            attributes: [
                Attribute(name: "class", value: "article-card__action article-card__favorite"),
                Attribute(name: "aria-label", value: article.isFavorite ? "Remove from favorites" : "Add to favorites"),
                Attribute(name: "data-article-id", value: article.id),
                Attribute(name: "data-action", value: "toggle-favorite")
            ],
            children: [AnyNode(Text(favoriteIcon))]
        )

        // Read indicator
        let readIndicator = Element<AnyHTMLContext>(
            tag: "span",
            attributes: [
                Attribute(name: "class", value: "article-card__read-indicator"),
                Attribute(name: "aria-label", value: article.isRead ? "Read" : "Unread")
            ],
            children: [AnyNode(Text(article.isRead ? "✓" : "•"))]
        )

        // Read more link
        let readMore = Element<AnyHTMLContext>(
            tag: "a",
            attributes: [
                Attribute(name: "href", value: article.url),
                Attribute(name: "class", value: "article-card__link"),
                Attribute(name: "target", value: "_blank"),
                Attribute(name: "rel", value: "noopener noreferrer"),
                Attribute(name: "data-article-id", value: article.id),
                Attribute(name: "data-action", value: "read-more")
            ],
            children: [AnyNode(Text("Read more →"))]
        )

        return Element<AnyHTMLContext>(
            tag: "footer",
            attributes: [Attribute(name: "class", value: "article-card__footer")],
            children: [
                AnyNode(favoriteButton),
                AnyNode(readIndicator),
                AnyNode(readMore)
            ]
        )
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
