import Foundation
import LINKER

/// Feed manager component for managing RSS/Atom feed subscriptions.
///
/// Simplified UI: URL input at top, feed list below. One-step add flow.
public struct FeedManager {

    // MARK: - Types

    /// Feed manager view mode
    public enum ViewMode {
        case list
        case add
        case edit(feedId: String)
    }

    // MARK: - Props

    public struct Props {
        public let feeds: [Feed]
        public let viewMode: ViewMode
        public let isLoading: Bool
        public let error: String?
        public let onAddFeed: (String) -> Void
        public let onEditFeed: (Feed) -> Void
        public let onDeleteFeed: (String) -> Void
        public let onToggleFeed: (String) -> Void
        public let onRefreshFeed: (String) -> Void
        public let onChangeMode: (ViewMode) -> Void
        public let onClose: () -> Void

        public init(
            feeds: [Feed],
            viewMode: ViewMode = .list,
            isLoading: Bool = false,
            error: String? = nil,
            onAddFeed: @escaping (String) -> Void,
            onEditFeed: @escaping (Feed) -> Void,
            onDeleteFeed: @escaping (String) -> Void,
            onToggleFeed: @escaping (String) -> Void,
            onRefreshFeed: @escaping (String) -> Void,
            onChangeMode: @escaping (ViewMode) -> Void,
            onClose: @escaping () -> Void
        ) {
            self.feeds = feeds
            self.viewMode = viewMode
            self.isLoading = isLoading
            self.error = error
            self.onAddFeed = onAddFeed
            self.onEditFeed = onEditFeed
            self.onDeleteFeed = onDeleteFeed
            self.onToggleFeed = onToggleFeed
            self.onRefreshFeed = onRefreshFeed
            self.onChangeMode = onChangeMode
            self.onClose = onClose
        }
    }

    // MARK: - Render

    public static func render(props: Props) -> [AnyNode] {
        var children: [AnyNode] = []

        // Header with title and close button
        children.append(AnyNode(renderHeader()))

        // Always show URL input at top for quick add
        children.append(AnyNode(renderAddInput()))

        // Error message (if any)
        if let error = props.error {
            children.append(AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "feed-manager__error")],
                children: [AnyNode(Text(error))]
            )))
        }

        // Feed list
        children.append(AnyNode(renderFeedList(feeds: props.feeds)))

        let container = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "feed-manager"),
                Attribute(name: "role", value: "dialog"),
                Attribute(name: "aria-label", value: "Feed Manager")
            ],
            children: children
        )

        return [AnyNode(container)]
    }

    // MARK: - Private Helpers

    private static func renderHeader() -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
            tag: "header",
            attributes: [Attribute(name: "class", value: "feed-manager__header")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "h2",
                    attributes: [Attribute(name: "class", value: "feed-manager__title")],
                    children: [AnyNode(Text("Feeds"))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "button",
                    attributes: [
                        Attribute(name: "type", value: "button"),
                        Attribute(name: "class", value: "feed-manager__close"),
                        Attribute(name: "aria-label", value: "Close"),
                        Attribute(name: "data-action", value: "close")
                    ],
                    children: [AnyNode(Text("✕"))]
                ))
            ]
        )
    }

    /// Simple URL input + Add button — always visible at the top.
    private static func renderAddInput() -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
            tag: "form",
            attributes: [
                Attribute(name: "class", value: "feed-form"),
                Attribute(name: "data-form", value: "add-feed")
            ],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "input",
                    attributes: [
                        Attribute(name: "type", value: "url"),
                        Attribute(name: "id", value: "feed-url"),
                        Attribute(name: "name", value: "url"),
                        Attribute(name: "placeholder", value: "Paste RSS feed URL..."),
                        Attribute(name: "required", value: "true"),
                        Attribute(name: "autocomplete", value: "url"),
                        Attribute(name: "class", value: "feed-form__input")
                    ],
                    children: []
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "button",
                    attributes: [
                        Attribute(name: "type", value: "submit"),
                        Attribute(name: "class", value: "feed-form__submit")
                    ],
                    children: [AnyNode(Text("Add"))]
                ))
            ]
        )
    }

    private static func renderFeedList(feeds: [Feed]) -> Element<AnyHTMLContext> {
        var children: [AnyNode] = []

        if feeds.isEmpty {
            children.append(AnyNode(Element<AnyHTMLContext>(
                tag: "p",
                attributes: [Attribute(name: "class", value: "feed-manager__empty")],
                children: [AnyNode(Text("No feeds yet. Paste a URL above to add one."))]
            )))
        } else {
            for feed in feeds {
                children.append(AnyNode(renderFeedItem(feed: feed)))
            }
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "feed-manager__list")],
            children: children
        )
    }

    private static func renderFeedItem(feed: Feed) -> Element<AnyHTMLContext> {
        let statusIcon = feed.isEnabled ? "" : " (paused)"
        let title = feed.title.isEmpty ? feed.url : feed.title

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "feed-item"),
                Attribute(name: "data-feed-id", value: feed.id)
            ],
            children: [
                // Feed info
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "feed-item__info")],
                    children: [
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "span",
                            attributes: [Attribute(name: "class", value: "feed-item__title")],
                            children: [AnyNode(Text("\(title)\(statusIcon)"))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "span",
                            attributes: [Attribute(name: "class", value: "feed-item__url")],
                            children: [AnyNode(Text(feed.url))]
                        ))
                    ]
                )),
                // Actions: refresh + delete
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "feed-item__actions")],
                    children: [
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "button",
                            attributes: [
                                Attribute(name: "type", value: "button"),
                                Attribute(name: "class", value: "feed-item__action"),
                                Attribute(name: "aria-label", value: "Refresh"),
                                Attribute(name: "data-action", value: "refresh"),
                                Attribute(name: "data-feed-id", value: feed.id)
                            ],
                            children: [AnyNode(Text("🔄"))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "button",
                            attributes: [
                                Attribute(name: "type", value: "button"),
                                Attribute(name: "class", value: "feed-item__action feed-item__action--danger"),
                                Attribute(name: "aria-label", value: "Delete"),
                                Attribute(name: "data-action", value: "delete"),
                                Attribute(name: "data-feed-id", value: feed.id)
                            ],
                            children: [AnyNode(Text("🗑️"))]
                        ))
                    ]
                ))
            ]
        )
    }
}
