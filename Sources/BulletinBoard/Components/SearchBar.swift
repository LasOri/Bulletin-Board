import Foundation
import LINKER

/// Search bar component with live search capabilities.
///
/// Provides text input for searching articles with optional filters
/// and search suggestions.
public struct SearchBar {

    // MARK: - Props

    public struct Props {
        public let query: String
        public let placeholder: String
        public let isSearching: Bool
        public let resultCount: Int?
        public let onQueryChange: (String) -> Void
        public let onClear: () -> Void

        public init(
            query: String = "",
            placeholder: String = "Search articles...",
            isSearching: Bool = false,
            resultCount: Int? = nil,
            onQueryChange: @escaping (String) -> Void,
            onClear: @escaping () -> Void
        ) {
            self.query = query
            self.placeholder = placeholder
            self.isSearching = isSearching
            self.resultCount = resultCount
            self.onQueryChange = onQueryChange
            self.onClear = onClear
        }
    }

    // MARK: - Render

    public static func render(props: Props) -> [AnyNode] {
        let container = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: containerClasses(props: props))
            ],
            children: [
                AnyNode(renderSearchInput(props: props)),
                AnyNode(renderSearchActions(props: props)),
                AnyNode(renderSearchStatus(props: props))
            ]
        )

        return [AnyNode(container)]
    }

    // MARK: - Private Helpers

    private static func containerClasses(props: Props) -> String {
        var classes = ["search-bar"]
        if props.isSearching {
            classes.append("search-bar--searching")
        }
        if !props.query.isEmpty {
            classes.append("search-bar--active")
        }
        return classes.joined(separator: " ")
    }

    private static func renderSearchInput(props: Props) -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
            tag: "input",
            attributes: [
                Attribute(name: "type", value: "text"),
                Attribute(name: "id", value: "search-input"),
                Attribute(name: "class", value: "search-bar__input"),
                Attribute(name: "placeholder", value: props.placeholder),
                Attribute(name: "value", value: props.query),
                Attribute(name: "aria-label", value: "Search articles"),
                Attribute(name: "data-search-input", value: "true")
            ],
            children: []
        )
    }

    private static func renderSearchActions(props: Props) -> Element<AnyHTMLContext> {
        var children: [AnyNode] = []

        // Search icon (magnifying glass)
        let searchIcon = Element<AnyHTMLContext>(
            tag: "span",
            attributes: [
                Attribute(name: "class", value: "search-bar__icon"),
                Attribute(name: "aria-hidden", value: "true")
            ],
            children: [AnyNode(Text("🔍"))]
        )
        children.append(AnyNode(searchIcon))

        // Clear button (only show when query is not empty)
        if !props.query.isEmpty {
            let clearButton = Element<AnyHTMLContext>(
                tag: "button",
                attributes: [
                    Attribute(name: "type", value: "button"),
                    Attribute(name: "class", value: "search-bar__clear"),
                    Attribute(name: "aria-label", value: "Clear search"),
                    Attribute(name: "data-action", value: "clear-search")
                ],
                children: [AnyNode(Text("✕"))]
            )
            children.append(AnyNode(clearButton))
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "search-bar__actions")],
            children: children
        )
    }

    private static func renderSearchStatus(props: Props) -> Element<AnyHTMLContext> {
        var children: [AnyNode] = []

        if props.isSearching {
            // Show searching indicator
            let searching = Element<AnyHTMLContext>(
                tag: "span",
                attributes: [Attribute(name: "class", value: "search-bar__status search-bar__status--searching")],
                children: [AnyNode(Text("Searching..."))]
            )
            children.append(AnyNode(searching))
        } else if let count = props.resultCount, !props.query.isEmpty {
            // Show result count
            let resultText = count == 1 ? "1 result" : "\(count) results"
            let status = Element<AnyHTMLContext>(
                tag: "span",
                attributes: [Attribute(name: "class", value: "search-bar__status search-bar__status--results")],
                children: [AnyNode(Text(resultText))]
            )
            children.append(AnyNode(status))
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "search-bar__status-container")],
            children: children
        )
    }
}

// MARK: - Search Suggestions

extension SearchBar {

    /// Search suggestion item
    public struct Suggestion: Equatable {
        public let id: String
        public let text: String
        public let type: SuggestionType
        public let matchCount: Int?

        public init(
            id: String,
            text: String,
            type: SuggestionType,
            matchCount: Int? = nil
        ) {
            self.id = id
            self.text = text
            self.type = type
            self.matchCount = matchCount
        }
    }

    /// Type of search suggestion
    public enum SuggestionType: String, Equatable {
        case keyword = "keyword"
        case category = "category"
        case feed = "feed"
        case recent = "recent"
    }

    /// Props for search bar with suggestions
    public struct SuggestionsProps {
        public let query: String
        public let placeholder: String
        public let isSearching: Bool
        public let resultCount: Int?
        public let suggestions: [Suggestion]
        public let showSuggestions: Bool
        public let onQueryChange: (String) -> Void
        public let onClear: () -> Void
        public let onSuggestionSelect: (Suggestion) -> Void

        public init(
            query: String = "",
            placeholder: String = "Search articles...",
            isSearching: Bool = false,
            resultCount: Int? = nil,
            suggestions: [Suggestion] = [],
            showSuggestions: Bool = false,
            onQueryChange: @escaping (String) -> Void,
            onClear: @escaping () -> Void,
            onSuggestionSelect: @escaping (Suggestion) -> Void
        ) {
            self.query = query
            self.placeholder = placeholder
            self.isSearching = isSearching
            self.resultCount = resultCount
            self.suggestions = suggestions
            self.showSuggestions = showSuggestions
            self.onQueryChange = onQueryChange
            self.onClear = onClear
            self.onSuggestionSelect = onSuggestionSelect
        }
    }

    /// Render search bar with suggestions
    public static func renderWithSuggestions(props: SuggestionsProps) -> [AnyNode] {
        let baseProps = Props(
            query: props.query,
            placeholder: props.placeholder,
            isSearching: props.isSearching,
            resultCount: props.resultCount,
            onQueryChange: props.onQueryChange,
            onClear: props.onClear
        )

        var children = render(props: baseProps)

        // Add suggestions dropdown if visible
        if props.showSuggestions && !props.suggestions.isEmpty {
            let suggestionsDropdown = renderSuggestionsDropdown(
                suggestions: props.suggestions
            )
            children.append(AnyNode(suggestionsDropdown))
        }

        return children
    }

    private static func renderSuggestionsDropdown(
        suggestions: [Suggestion]
    ) -> Element<AnyHTMLContext> {
        let suggestionItems = suggestions.map { suggestion in
            renderSuggestionItem(suggestion: suggestion)
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "search-bar__suggestions"),
                Attribute(name: "role", value: "listbox")
            ],
            children: suggestionItems.map { AnyNode($0) }
        )
    }

    private static func renderSuggestionItem(
        suggestion: Suggestion
    ) -> Element<AnyHTMLContext> {
        var children: [AnyNode] = []

        // Type icon
        let icon = suggestionIcon(for: suggestion.type)
        let iconElement = Element<AnyHTMLContext>(
            tag: "span",
            attributes: [
                Attribute(name: "class", value: "search-bar__suggestion-icon"),
                Attribute(name: "aria-hidden", value: "true")
            ],
            children: [AnyNode(Text(icon))]
        )
        children.append(AnyNode(iconElement))

        // Suggestion text
        let textElement = Element<AnyHTMLContext>(
            tag: "span",
            attributes: [Attribute(name: "class", value: "search-bar__suggestion-text")],
            children: [AnyNode(Text(suggestion.text))]
        )
        children.append(AnyNode(textElement))

        // Match count (if available)
        if let count = suggestion.matchCount {
            let countText = "(\(count))"
            let countElement = Element<AnyHTMLContext>(
                tag: "span",
                attributes: [Attribute(name: "class", value: "search-bar__suggestion-count")],
                children: [AnyNode(Text(countText))]
            )
            children.append(AnyNode(countElement))
        }

        return Element<AnyHTMLContext>(
            tag: "button",
            attributes: [
                Attribute(name: "type", value: "button"),
                Attribute(name: "class", value: "search-bar__suggestion-item"),
                Attribute(name: "role", value: "option"),
                Attribute(name: "data-suggestion-id", value: suggestion.id),
                Attribute(name: "data-suggestion-type", value: suggestion.type.rawValue)
            ],
            children: children
        )
    }

    private static func suggestionIcon(for type: SuggestionType) -> String {
        switch type {
        case .keyword: return "🔖"
        case .category: return "📁"
        case .feed: return "📰"
        case .recent: return "🕐"
        }
    }
}
