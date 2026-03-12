import Foundation
import LINKER

/// Feed manager component for managing RSS/Atom feed subscriptions.
///
/// Provides UI for adding, editing, removing, and managing feed subscriptions
/// with validation and error handling.
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
        let container = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "feed-manager"),
                Attribute(name: "role", value: "dialog"),
                Attribute(name: "aria-label", value: "Feed Manager")
            ],
            children: [
                AnyNode(renderHeader(props: props)),
                AnyNode(renderContent(props: props)),
                AnyNode(renderFooter(props: props))
            ]
        )

        return [AnyNode(container)]
    }

    // MARK: - Private Helpers

    private static func renderHeader(props: Props) -> Element<AnyHTMLContext> {
        let title = titleForMode(props.viewMode)

        var children: [AnyNode] = []

        // Title
        let titleElement = Element<AnyHTMLContext>(
            tag: "h2",
            attributes: [Attribute(name: "class", value: "feed-manager__title")],
            children: [AnyNode(Text(title))]
        )
        children.append(AnyNode(titleElement))

        // Close button
        let closeButton = Element<AnyHTMLContext>(
            tag: "button",
            attributes: [
                Attribute(name: "type", value: "button"),
                Attribute(name: "class", value: "feed-manager__close"),
                Attribute(name: "aria-label", value: "Close feed manager"),
                Attribute(name: "data-action", value: "close")
            ],
            children: [AnyNode(Text("✕"))]
        )
        children.append(AnyNode(closeButton))

        return Element<AnyHTMLContext>(
            tag: "header",
            attributes: [Attribute(name: "class", value: "feed-manager__header")],
            children: children
        )
    }

    private static func titleForMode(_ mode: ViewMode) -> String {
        switch mode {
        case .list: return "Manage Feeds"
        case .add: return "Add New Feed"
        case .edit: return "Edit Feed"
        }
    }

    private static func renderContent(props: Props) -> Element<AnyHTMLContext> {
        var children: [AnyNode] = []

        // Error message (if any)
        if let error = props.error {
            children.append(contentsOf: ErrorMessage.error(
                message: error,
                onDismiss: { }
            ))
        }

        // Loading state
        if props.isLoading {
            children.append(contentsOf: LoadingSpinner.medium(message: "Loading feeds..."))
        } else {
            // Mode-specific content
            switch props.viewMode {
            case .list:
                children.append(AnyNode(renderFeedList(feeds: props.feeds, props: props)))
            case .add:
                children.append(AnyNode(renderAddFeedForm()))
            case .edit(let feedId):
                if let feed = props.feeds.first(where: { $0.id == feedId }) {
                    children.append(AnyNode(renderEditFeedForm(feed: feed)))
                }
            }
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "feed-manager__content")],
            children: children
        )
    }

    private static func renderFeedList(feeds: [Feed], props: Props) -> Element<AnyHTMLContext> {
        var children: [AnyNode] = []

        if feeds.isEmpty {
            // Empty state
            let emptyState = Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "feed-manager__empty")],
                children: [
                    AnyNode(Element<AnyHTMLContext>(
                        tag: "p",
                        children: [AnyNode(Text("No feeds yet. Add your first RSS/Atom feed to get started!"))]
                    ))
                ]
            )
            children.append(AnyNode(emptyState))
        } else {
            // Feed items
            for feed in feeds {
                children.append(AnyNode(renderFeedItem(feed: feed, props: props)))
            }
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "feed-manager__list")],
            children: children
        )
    }

    private static func renderFeedItem(feed: Feed, props: Props) -> Element<AnyHTMLContext> {
        var children: [AnyNode] = []

        // Feed info
        let info = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "feed-item__info")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "h3",
                    attributes: [Attribute(name: "class", value: "feed-item__title")],
                    children: [AnyNode(Text(feed.title))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "p",
                    attributes: [Attribute(name: "class", value: "feed-item__url")],
                    children: [AnyNode(Text(feed.url))]
                )),
                AnyNode(renderFeedStats(feed: feed))
            ]
        )
        children.append(AnyNode(info))

        // Actions
        let actions = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "feed-item__actions")],
            children: [
                AnyNode(renderToggleButton(feed: feed)),
                AnyNode(renderRefreshButton(feed: feed)),
                AnyNode(renderEditButton(feed: feed)),
                AnyNode(renderDeleteButton(feed: feed))
            ]
        )
        children.append(AnyNode(actions))

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: feedItemClasses(feed: feed)),
                Attribute(name: "data-feed-id", value: feed.id)
            ],
            children: children
        )
    }

    private static func feedItemClasses(feed: Feed) -> String {
        var classes = ["feed-item"]
        if !feed.isEnabled {
            classes.append("feed-item--disabled")
        }
        if feed.isFetching {
            classes.append("feed-item--fetching")
        }
        if feed.lastError != nil {
            classes.append("feed-item--error")
        }
        return classes.joined(separator: " ")
    }

    private static func renderFeedStats(feed: Feed) -> Element<AnyHTMLContext> {
        var stats: [String] = []

        stats.append("\(feed.articleCount) articles")
        if feed.unreadCount > 0 {
            stats.append("\(feed.unreadCount) unread")
        }

        if let lastFetch = feed.lastSuccessfulFetch {
            #if !arch(wasm32)
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            let timeAgo = formatter.localizedString(for: lastFetch, relativeTo: Date())
            #else
            // WASM: Simple time ago calculation
            let seconds = Date().timeIntervalSince(lastFetch)
            let timeAgo: String
            if seconds < 60 {
                timeAgo = "just now"
            } else if seconds < 3600 {
                let minutes = Int(seconds / 60)
                timeAgo = "\(minutes)m ago"
            } else if seconds < 86400 {
                let hours = Int(seconds / 3600)
                timeAgo = "\(hours)h ago"
            } else {
                let days = Int(seconds / 86400)
                timeAgo = "\(days)d ago"
            }
            #endif
            stats.append("Updated \(timeAgo)")
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "feed-item__stats")],
            children: [AnyNode(Text(stats.joined(separator: " • ")))]
        )
    }

    private static func renderToggleButton(feed: Feed) -> Element<AnyHTMLContext> {
        let label = feed.isEnabled ? "Disable" : "Enable"
        let icon = feed.isEnabled ? "⏸" : "▶️"

        return Element<AnyHTMLContext>(
            tag: "button",
            attributes: [
                Attribute(name: "type", value: "button"),
                Attribute(name: "class", value: "feed-item__action"),
                Attribute(name: "aria-label", value: label),
                Attribute(name: "data-action", value: "toggle"),
                Attribute(name: "data-feed-id", value: feed.id)
            ],
            children: [AnyNode(Text(icon))]
        )
    }

    private static func renderRefreshButton(feed: Feed) -> Element<AnyHTMLContext> {
        var attrs = [
            Attribute(name: "type", value: "button"),
            Attribute(name: "class", value: "feed-item__action"),
            Attribute(name: "aria-label", value: "Refresh feed"),
            Attribute(name: "data-action", value: "refresh"),
            Attribute(name: "data-feed-id", value: feed.id),
        ]
        if feed.isFetching {
            attrs.append(Attribute(name: "disabled"))
        }
        return Element<AnyHTMLContext>(
            tag: "button",
            attributes: attrs,
            children: [AnyNode(Text("🔄"))]
        )
    }

    private static func renderEditButton(feed: Feed) -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
            tag: "button",
            attributes: [
                Attribute(name: "type", value: "button"),
                Attribute(name: "class", value: "feed-item__action"),
                Attribute(name: "aria-label", value: "Edit feed"),
                Attribute(name: "data-action", value: "edit"),
                Attribute(name: "data-feed-id", value: feed.id)
            ],
            children: [AnyNode(Text("✏️"))]
        )
    }

    private static func renderDeleteButton(feed: Feed) -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
            tag: "button",
            attributes: [
                Attribute(name: "type", value: "button"),
                Attribute(name: "class", value: "feed-item__action feed-item__action--danger"),
                Attribute(name: "aria-label", value: "Delete feed"),
                Attribute(name: "data-action", value: "delete"),
                Attribute(name: "data-feed-id", value: feed.id)
            ],
            children: [AnyNode(Text("🗑️"))]
        )
    }

    private static func renderAddFeedForm() -> Element<AnyHTMLContext> {
        // Get CSRF token for form protection
        let csrfToken = SecurityManager.shared.csrfManager.getToken()

        return Element<AnyHTMLContext>(
            tag: "form",
            attributes: [
                Attribute(name: "class", value: "feed-form"),
                Attribute(name: "data-form", value: "add-feed")
            ],
            children: [
                // CSRF Protection: Hidden token field
                AnyNode(Element<AnyHTMLContext>(
                    tag: "input",
                    attributes: [
                        Attribute(name: "type", value: "hidden"),
                        Attribute(name: "name", value: "csrf_token"),
                        Attribute(name: "value", value: csrfToken)
                    ],
                    children: []
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "label",
                    attributes: [Attribute(name: "for", value: "feed-url")],
                    children: [AnyNode(Text("Feed URL"))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "input",
                    attributes: [
                        Attribute(name: "type", value: "url"),
                        Attribute(name: "id", value: "feed-url"),
                        Attribute(name: "name", value: "url"),
                        Attribute(name: "placeholder", value: "https://example.com/feed.xml"),
                        Attribute(name: "required", value: "true"),
                        Attribute(name: "autocomplete", value: "url")
                    ],
                    children: []
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "button",
                    attributes: [
                        Attribute(name: "type", value: "submit"),
                        Attribute(name: "class", value: "feed-form__submit")
                    ],
                    children: [AnyNode(Text("Add Feed"))]
                ))
            ]
        )
    }

    private static func renderEditFeedForm(feed: Feed) -> Element<AnyHTMLContext> {
        // Get CSRF token for form protection
        let csrfToken = SecurityManager.shared.csrfManager.getToken()

        return Element<AnyHTMLContext>(
            tag: "form",
            attributes: [
                Attribute(name: "class", value: "feed-form"),
                Attribute(name: "data-form", value: "edit-feed"),
                Attribute(name: "data-feed-id", value: feed.id)
            ],
            children: [
                // CSRF Protection: Hidden token field
                AnyNode(Element<AnyHTMLContext>(
                    tag: "input",
                    attributes: [
                        Attribute(name: "type", value: "hidden"),
                        Attribute(name: "name", value: "csrf_token"),
                        Attribute(name: "value", value: csrfToken)
                    ],
                    children: []
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "label",
                    attributes: [Attribute(name: "for", value: "feed-title")],
                    children: [AnyNode(Text("Title"))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "input",
                    attributes: [
                        Attribute(name: "type", value: "text"),
                        Attribute(name: "id", value: "feed-title"),
                        Attribute(name: "name", value: "title"),
                        Attribute(name: "value", value: feed.title),
                        Attribute(name: "required", value: "true")
                    ],
                    children: []
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "label",
                    attributes: [Attribute(name: "for", value: "feed-category")],
                    children: [AnyNode(Text("Category (optional)"))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "input",
                    attributes: [
                        Attribute(name: "type", value: "text"),
                        Attribute(name: "id", value: "feed-category"),
                        Attribute(name: "name", value: "category"),
                        Attribute(name: "value", value: feed.userCategory ?? "")
                    ],
                    children: []
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "button",
                    attributes: [
                        Attribute(name: "type", value: "submit"),
                        Attribute(name: "class", value: "feed-form__submit")
                    ],
                    children: [AnyNode(Text("Save Changes"))]
                ))
            ]
        )
    }

    private static func renderFooter(props: Props) -> Element<AnyHTMLContext> {
        var children: [AnyNode] = []

        switch props.viewMode {
        case .list:
            // Add feed button
            let addButton = Element<AnyHTMLContext>(
                tag: "button",
                attributes: [
                    Attribute(name: "type", value: "button"),
                    Attribute(name: "class", value: "feed-manager__add"),
                    Attribute(name: "data-action", value: "show-add-form")
                ],
                children: [AnyNode(Text("+ Add Feed"))]
            )
            children.append(AnyNode(addButton))

        case .add, .edit:
            // Cancel button
            let cancelButton = Element<AnyHTMLContext>(
                tag: "button",
                attributes: [
                    Attribute(name: "type", value: "button"),
                    Attribute(name: "class", value: "feed-manager__cancel"),
                    Attribute(name: "data-action", value: "show-list")
                ],
                children: [AnyNode(Text("Cancel"))]
            )
            children.append(AnyNode(cancelButton))
        }

        return Element<AnyHTMLContext>(
            tag: "footer",
            attributes: [Attribute(name: "class", value: "feed-manager__footer")],
            children: children
        )
    }
}
