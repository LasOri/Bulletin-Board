import LINKER

public struct FeedManager {

    public enum ViewMode {
        case list
        case add
        case edit(feedId: String)
    }

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

    public static func render(props: Props) -> [AnyNode] {
        var children: [AnyNode] = []

        children.append(AnyNode(renderHeader()))

        children.append(AnyNode(renderAddInput()))

        if let error = props.error {
            children.append(AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "feed-manager__error")],
                children: [AnyNode(Text(error))]
            )))
        }

        children.append(AnyNode(renderFeedList(feeds: props.feeds)))

        children.append(AnyNode(renderOPMLActions()))

        var feedManagerClass = "feed-manager"
        if GPUComponentConfig.isEnabled(for: "FeedManager") {
            feedManagerClass += " feed-manager--blurred"
        }

        let container = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: feedManagerClass),
                Attribute(name: "role", value: "dialog"),
                Attribute(name: "aria-modal", value: "true"),
                Attribute(name: "aria-label", value: "Feed Manager")
            ],
            children: children
        )

        return [AnyNode(container)]
    }

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
                    children: [AnyNode(Icons.close(size: 16))]
                ))
            ]
        )
    }

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

        var infoChildren: [AnyNode] = [
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

        let frequencyOptions: [(String, String)] = [
            ("15", "15 min"),
            ("30", "30 min"),
            ("60", "1 hour"),
            ("120", "2 hours"),
            ("240", "4 hours"),
            ("480", "8 hours"),
            ("1440", "24 hours")
        ]

        let selectChildren: [AnyNode] = frequencyOptions.map { (value, label) in
            var attrs = [
                Attribute(name: "value", value: value)
            ]
            if String(feed.updateFrequency) == value {
                attrs.append(Attribute(name: "selected", value: "true"))
            }
            return AnyNode(Element<AnyHTMLContext>(
                tag: "option",
                attributes: attrs,
                children: [AnyNode(Text(label))]
            ))
        }

        let editForm = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "feed-item__edit-form")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "input",
                    attributes: [
                        Attribute(name: "type", value: "text"),
                        Attribute(name: "id", value: "edit-feed-title-\(feed.id)"),
                        Attribute(name: "class", value: "feed-item__edit-input"),
                        Attribute(name: "value", value: feed.title),
                        Attribute(name: "placeholder", value: "Feed title")
                    ],
                    children: []
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "feed-item__frequency")],
                    children: [
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "label",
                            attributes: [
                                Attribute(name: "class", value: "feed-item__frequency-label"),
                                Attribute(name: "for", value: "edit-feed-freq-\(feed.id)")
                            ],
                            children: [AnyNode(Icons.clock(size: 12)), AnyNode(Text(" Refresh"))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "select",
                            attributes: [
                                Attribute(name: "id", value: "edit-feed-freq-\(feed.id)"),
                                Attribute(name: "class", value: "feed-item__frequency-select"),
                                Attribute(name: "data-feed-id", value: feed.id)
                            ],
                            children: selectChildren
                        ))
                    ]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "button",
                    attributes: [
                        Attribute(name: "type", value: "button"),
                        Attribute(name: "class", value: "feed-item__edit-save"),
                        Attribute(name: "data-action", value: "save-feed-edit"),
                        Attribute(name: "data-feed-id", value: feed.id)
                    ],
                    children: [AnyNode(Text("Save"))]
                ))
            ]
        )
        infoChildren.append(AnyNode(editForm))

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "feed-item"),
                Attribute(name: "data-feed-id", value: feed.id)
            ],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "feed-item__info")],
                    children: infoChildren
                )),
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
                            children: [AnyNode(Icons.refresh())]
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
                            children: [AnyNode(Icons.trash())]
                        ))
                    ]
                ))
            ]
        )
    }

    private static func renderOPMLActions() -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "feed-manager__opml")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "button",
                    attributes: [
                        Attribute(name: "type", value: "button"),
                        Attribute(name: "class", value: "toolbar-button"),
                        Attribute(name: "data-action", value: "import-opml"),
                        Attribute(name: "aria-label", value: "Import OPML")
                    ],
                    children: [AnyNode(Icons.wrap(Icons.download())), AnyNode(Text(" Import OPML"))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "button",
                    attributes: [
                        Attribute(name: "type", value: "button"),
                        Attribute(name: "class", value: "toolbar-button"),
                        Attribute(name: "data-action", value: "export-opml"),
                        Attribute(name: "aria-label", value: "Export OPML")
                    ],
                    children: [AnyNode(Icons.wrap(Icons.upload())), AnyNode(Text(" Export OPML"))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "input",
                    attributes: [
                        Attribute(name: "type", value: "file"),
                        Attribute(name: "id", value: "opml-file-input"),
                        Attribute(name: "accept", value: ".opml,.xml"),
                        Attribute(name: "style", value: "display:none")
                    ],
                    children: []
                ))
            ]
        )
    }
}

