import Foundation
import LINKER

public struct ArticleDetailView {

    public struct Props {
        public let article: Article
        public let relatedArticles: [Article]

        public init(article: Article, relatedArticles: [Article] = []) {
            self.article = article
            self.relatedArticles = relatedArticles
        }
    }

    public static func render(props: Props) -> [AnyNode] {
        let article = props.article
        let relatedArticles = props.relatedArticles

        let backdrop = BlurView(id: "article-detail-backdrop", style: .frostedGlass, intensity: 1.0) {
            return [AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [
                    Attribute(name: "class", value: "article-detail-overlay"),
                    Attribute(name: "data-action", value: "collapse-article-overlay")
                ],
                children: [
                    AnyNode(renderContentCard(article: article, relatedArticles: relatedArticles))
                ]
            ))]
        }

        return backdrop
    }

    static func renderContentCard(article: Article, relatedArticles: [Article] = []) -> Element<AnyHTMLContext> {
        var children: [AnyNode] = []

        children.append(AnyNode(renderCloseButton()))

        if let enclosure = article.enclosure, enclosure.type.starts(with: "image/") {
            children.append(AnyNode(renderHeroImage(url: enclosure.url, alt: article.title)))
        }

        children.append(AnyNode(renderHeader(article: article)))

        children.append(AnyNode(renderBody(article: article)))

        if !article.keywords.isEmpty {
            children.append(AnyNode(renderKeywords(keywords: article.keywords)))
        }

        if !relatedArticles.isEmpty {
            children.append(AnyNode(renderRelatedArticles(articles: relatedArticles)))
        }

        children.append(AnyNode(renderFooter(article: article)))

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "article-detail"),
                Attribute(name: "data-article-id", value: article.id)
            ],
            children: children
        )
    }

    private static func renderCloseButton() -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
            tag: "button",
            attributes: [
                Attribute(name: "type", value: "button"),
                Attribute(name: "class", value: "article-detail__close-btn"),
                Attribute(name: "data-action", value: "collapse-article"),
                Attribute(name: "aria-label", value: "Close article")
            ],
            children: [AnyNode(Text("\u{2715}"))]
        )
    }

    private static func renderHeroImage(url: String, alt: String) -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "article-detail__hero")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "img",
                    attributes: [
                        Attribute(name: "src", value: url),
                        Attribute(name: "alt", value: alt),
                        Attribute(name: "class", value: "article-detail__hero-img"),
                        Attribute(name: "crossorigin", value: "anonymous"),
                        Attribute(name: "onerror", value: "this.style.display='none';this.parentElement.classList.add('article-detail__hero--placeholder')")
                    ]
                ))
            ]
        )
    }

    private static func renderHeader(article: Article) -> Element<AnyHTMLContext> {
        var headerChildren: [AnyNode] = []

        var badgeRow: [AnyNode] = []
        if let category = article.autoCategory {
            badgeRow.append(AnyNode(Element<AnyHTMLContext>(
                tag: "button",
                attributes: [
                    Attribute(name: "type", value: "button"),
                    Attribute(name: "class", value: "article-detail__category"),
                    Attribute(name: "style", value: "background-color: \(category.color)"),
                    Attribute(name: "data-action", value: "filter-category"),
                    Attribute(name: "data-category", value: category.rawValue)
                ],
                children: [AnyNode(Text(category.rawValue))]
            )))
        }
        if let sentiment = article.sentimentLabel, let emoji = article.sentimentEmoji {
            let sentimentClass = "sentiment-indicator sentiment--\(sentiment.lowercased())"
            badgeRow.append(AnyNode(Element<AnyHTMLContext>(
                tag: "span",
                attributes: [Attribute(name: "class", value: sentimentClass)],
                children: [AnyNode(Text("\(emoji) \(sentiment)"))]
            )))
        }
        if !badgeRow.isEmpty {
            headerChildren.append(AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "article-detail__badges")],
                children: badgeRow
            )))
        }

        headerChildren.append(AnyNode(Element<AnyHTMLContext>(
            tag: "h1",
            attributes: [Attribute(name: "class", value: "article-detail__title")],
            children: [AnyNode(Text(article.title))]
        )))

        var metaParts: [String] = []
        if let author = article.author {
            metaParts.append(author)
        }
        if let publishedAt = article.publishedAt {
            metaParts.append(formatDate(publishedAt))
        }
        if !metaParts.isEmpty {
            headerChildren.append(AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "article-detail__metadata")],
                children: [AnyNode(Text(metaParts.joined(separator: " \u{2022} ")))]
            )))
        }

        return Element<AnyHTMLContext>(
            tag: "header",
            attributes: [Attribute(name: "class", value: "article-detail__header")],
            children: headerChildren
        )
    }

    private static func renderBody(article: Article) -> Element<AnyHTMLContext> {
        let text = article.content ?? article.description ?? article.nlpSummary ?? ""

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "article-detail__body")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "p",
                    children: [AnyNode(Text(text))]
                ))
            ]
        )
    }

    private static func renderKeywords(keywords: [String]) -> Element<AnyHTMLContext> {
        let keywordNodes = keywords.map { keyword in
            AnyNode(Element<AnyHTMLContext>(
                tag: "span",
                attributes: [Attribute(name: "class", value: "article-detail__keyword")],
                children: [AnyNode(Text(keyword))]
            ))
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "article-detail__keywords")],
            children: keywordNodes
        )
    }

    private static func renderRelatedArticles(articles: [Article]) -> Element<AnyHTMLContext> {
        let header = Element<AnyHTMLContext>(
            tag: "h3",
            attributes: [Attribute(name: "class", value: "related-articles__title")],
            children: [AnyNode(Text("Related Articles"))]
        )

        let items = articles.prefix(3).map { article in
            var itemChildren: [AnyNode] = []

            itemChildren.append(AnyNode(Element<AnyHTMLContext>(
                tag: "span",
                attributes: [Attribute(name: "class", value: "related-article-item__title")],
                children: [AnyNode(Text(article.title))]
            )))

            if let category = article.autoCategory {
                itemChildren.append(AnyNode(Element<AnyHTMLContext>(
                    tag: "span",
                    attributes: [
                        Attribute(name: "class", value: "related-article-item__category"),
                        Attribute(name: "style", value: "background-color: \(category.color)")
                    ],
                    children: [AnyNode(Text(category.rawValue))]
                )))
            }

            return AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [
                    Attribute(name: "class", value: "related-article-item"),
                    Attribute(name: "data-action", value: "article-click"),
                    Attribute(name: "data-article-id", value: article.id)
                ],
                children: itemChildren
            ))
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "related-articles")],
            children: [AnyNode(header)] + items
        )
    }

    private static func renderFooter(article: Article) -> Element<AnyHTMLContext> {
        let favoriteIcon = article.isFavorite ? "\u{2605}" : "\u{2606}"
        let favoriteLabel = article.isFavorite ? "Remove from favorites" : "Add to favorites"

        let archiveAction = article.isArchived ? "unarchive-article" : "archive-article"
        let archiveLabel = article.isArchived ? "Restore from archive" : "Archive article"
        let archiveText = article.isArchived ? "\u{1F4E4} Restore" : "\u{1F4E6} Archive"

        return Element<AnyHTMLContext>(
            tag: "footer",
            attributes: [Attribute(name: "class", value: "article-detail__footer")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "button",
                    attributes: [
                        Attribute(name: "type", value: "button"),
                        Attribute(name: "class", value: "article-detail__action"),
                        Attribute(name: "data-action", value: "toggle-favorite"),
                        Attribute(name: "data-article-id", value: article.id),
                        Attribute(name: "aria-label", value: favoriteLabel)
                    ],
                    children: [AnyNode(Text("\(favoriteIcon) Favorite"))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "button",
                    attributes: [
                        Attribute(name: "type", value: "button"),
                        Attribute(name: "class", value: "article-detail__action"),
                        Attribute(name: "data-action", value: "mark-read"),
                        Attribute(name: "data-article-id", value: article.id),
                        Attribute(name: "aria-label", value: article.isRead ? "Already read" : "Mark as read")
                    ],
                    children: [AnyNode(Text(article.isRead ? "\u{2713} Read" : "\u{25CF} Mark Read"))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "button",
                    attributes: [
                        Attribute(name: "type", value: "button"),
                        Attribute(name: "class", value: "article-detail__action"),
                        Attribute(name: "data-action", value: archiveAction),
                        Attribute(name: "data-article-id", value: article.id),
                        Attribute(name: "aria-label", value: archiveLabel)
                    ],
                    children: [AnyNode(Text(archiveText))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "a",
                    attributes: [
                        Attribute(name: "href", value: article.url),
                        Attribute(name: "class", value: "article-detail__action article-detail__action--primary"),
                        Attribute(name: "target", value: "_blank"),
                        Attribute(name: "rel", value: "noopener noreferrer")
                    ],
                    children: [AnyNode(Text("Open Original \u{2192}"))]
                ))
            ]
        )
    }

    private static func formatDate(_ date: Date) -> String {
        #if !arch(wasm32)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
        #else
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(seconds / 86400)
            return "\(days)d ago"
        }
        #endif
    }
}

