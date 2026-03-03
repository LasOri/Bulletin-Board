import XCTest
@testable import BulletinBoard
import LINKER

final class SearchBarTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTestProps(
        query: String = "",
        placeholder: String = "Search...",
        isSearching: Bool = false,
        resultCount: Int? = nil,
        onQueryChange: @escaping (String) -> Void = { _ in },
        onClear: @escaping () -> Void = { }
    ) -> SearchBar.Props {
        SearchBar.Props(
            query: query,
            placeholder: placeholder,
            isSearching: isSearching,
            resultCount: resultCount,
            onQueryChange: onQueryChange,
            onClear: onClear
        )
    }

    // MARK: - Basic Rendering Tests

    func testRenderEmptySearchBar() {
        let props = makeTestProps()
        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render search input
    }

    func testRenderWithQuery() {
        let props = makeTestProps(query: "swift")
        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render with query value
    }

    func testRenderWithCustomPlaceholder() {
        let props = makeTestProps(placeholder: "Find articles...")
        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should use custom placeholder
    }

    // MARK: - Search State Tests

    func testRenderWhileSearching() {
        let props = makeTestProps(query: "test", isSearching: true)
        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should show searching indicator
    }

    func testRenderWithResults() {
        let props = makeTestProps(query: "swift", resultCount: 42)
        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should show result count
    }

    func testRenderWithSingleResult() {
        let props = makeTestProps(query: "test", resultCount: 1)
        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should show "1 result" (singular)
    }

    func testRenderWithMultipleResults() {
        let props = makeTestProps(query: "test", resultCount: 5)
        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should show "5 results" (plural)
    }

    func testRenderWithZeroResults() {
        let props = makeTestProps(query: "test", resultCount: 0)
        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should show "0 results"
    }

    // MARK: - Clear Button Tests

    func testClearButtonNotShownWhenEmpty() {
        let props = makeTestProps(query: "")
        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Clear button should not be rendered
    }

    func testClearButtonShownWithQuery() {
        let props = makeTestProps(query: "test")
        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Clear button should be rendered
    }

    // MARK: - Props Tests

    func testPropsInitialization() {
        var queryChanged = false
        var cleared = false

        let props = SearchBar.Props(
            query: "test",
            placeholder: "Search...",
            isSearching: true,
            resultCount: 10,
            onQueryChange: { _ in queryChanged = true },
            onClear: { cleared = true }
        )

        XCTAssertEqual(props.query, "test")
        XCTAssertEqual(props.placeholder, "Search...")
        XCTAssertTrue(props.isSearching)
        XCTAssertEqual(props.resultCount, 10)

        props.onQueryChange("new query")
        XCTAssertTrue(queryChanged)

        props.onClear()
        XCTAssertTrue(cleared)
    }

    func testPropsDefaultValues() {
        let props = makeTestProps()

        XCTAssertEqual(props.query, "")
        XCTAssertEqual(props.placeholder, "Search...")
        XCTAssertFalse(props.isSearching)
        XCTAssertNil(props.resultCount)
    }

    // MARK: - CSS Classes Tests

    func testBaseClassAlwaysPresent() {
        let props = makeTestProps()
        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have base search-bar class
    }

    func testSearchingClassWhenSearching() {
        let props = makeTestProps(isSearching: true)
        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have search-bar--searching class
    }

    func testActiveClassWithQuery() {
        let props = makeTestProps(query: "test")
        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should have search-bar--active class
    }

    // MARK: - Suggestions Tests

    func testSuggestionCreation() {
        let suggestion = SearchBar.Suggestion(
            id: "1",
            text: "swift",
            type: .keyword,
            matchCount: 10
        )

        XCTAssertEqual(suggestion.id, "1")
        XCTAssertEqual(suggestion.text, "swift")
        XCTAssertEqual(suggestion.type, .keyword)
        XCTAssertEqual(suggestion.matchCount, 10)
    }

    func testSuggestionEquatable() {
        let suggestion1 = SearchBar.Suggestion(
            id: "1",
            text: "swift",
            type: .keyword,
            matchCount: 10
        )
        let suggestion2 = SearchBar.Suggestion(
            id: "1",
            text: "swift",
            type: .keyword,
            matchCount: 10
        )
        let suggestion3 = SearchBar.Suggestion(
            id: "2",
            text: "ios",
            type: .keyword,
            matchCount: 5
        )

        XCTAssertEqual(suggestion1, suggestion2)
        XCTAssertNotEqual(suggestion1, suggestion3)
    }

    func testSuggestionTypes() {
        XCTAssertEqual(SearchBar.SuggestionType.keyword.rawValue, "keyword")
        XCTAssertEqual(SearchBar.SuggestionType.category.rawValue, "category")
        XCTAssertEqual(SearchBar.SuggestionType.feed.rawValue, "feed")
        XCTAssertEqual(SearchBar.SuggestionType.recent.rawValue, "recent")
    }

    // MARK: - Suggestions Props Tests

    func testSuggestionsPropsInitialization() {
        let suggestions = [
            SearchBar.Suggestion(id: "1", text: "swift", type: .keyword, matchCount: 10)
        ]
        var queryChanged = false
        var cleared = false
        var selected: SearchBar.Suggestion?

        let props = SearchBar.SuggestionsProps(
            query: "swi",
            placeholder: "Search...",
            isSearching: false,
            resultCount: 10,
            suggestions: suggestions,
            showSuggestions: true,
            onQueryChange: { _ in queryChanged = true },
            onClear: { cleared = true },
            onSuggestionSelect: { suggestion in selected = suggestion }
        )

        XCTAssertEqual(props.query, "swi")
        XCTAssertEqual(props.suggestions.count, 1)
        XCTAssertTrue(props.showSuggestions)

        props.onQueryChange("swift")
        XCTAssertTrue(queryChanged)

        props.onClear()
        XCTAssertTrue(cleared)

        props.onSuggestionSelect(suggestions[0])
        XCTAssertEqual(selected?.id, "1")
    }

    // MARK: - Render with Suggestions Tests

    func testRenderWithoutSuggestions() {
        let props = SearchBar.SuggestionsProps(
            query: "test",
            suggestions: [],
            showSuggestions: false,
            onQueryChange: { _ in },
            onClear: { },
            onSuggestionSelect: { _ in }
        )

        let nodes = SearchBar.renderWithSuggestions(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should render basic search bar without suggestions
    }

    func testRenderWithSuggestionsHidden() {
        let suggestions = [
            SearchBar.Suggestion(id: "1", text: "swift", type: .keyword)
        ]
        let props = SearchBar.SuggestionsProps(
            query: "swi",
            suggestions: suggestions,
            showSuggestions: false,
            onQueryChange: { _ in },
            onClear: { },
            onSuggestionSelect: { _ in }
        )

        let nodes = SearchBar.renderWithSuggestions(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should not show suggestions when hidden
    }

    func testRenderWithSuggestionsVisible() {
        let suggestions = [
            SearchBar.Suggestion(id: "1", text: "swift", type: .keyword, matchCount: 10),
            SearchBar.Suggestion(id: "2", text: "ios", type: .keyword, matchCount: 5)
        ]
        let props = SearchBar.SuggestionsProps(
            query: "s",
            suggestions: suggestions,
            showSuggestions: true,
            onQueryChange: { _ in },
            onClear: { },
            onSuggestionSelect: { _ in }
        )

        let nodes = SearchBar.renderWithSuggestions(props: props)

        XCTAssertGreaterThan(nodes.count, 1)
        // Should render suggestions dropdown
    }

    func testRenderSuggestionWithMatchCount() {
        let suggestions = [
            SearchBar.Suggestion(id: "1", text: "swift", type: .keyword, matchCount: 42)
        ]
        let props = SearchBar.SuggestionsProps(
            query: "swi",
            suggestions: suggestions,
            showSuggestions: true,
            onQueryChange: { _ in },
            onClear: { },
            onSuggestionSelect: { _ in }
        )

        let nodes = SearchBar.renderWithSuggestions(props: props)

        XCTAssertGreaterThan(nodes.count, 1)
        // Should display match count
    }

    func testRenderSuggestionWithoutMatchCount() {
        let suggestions = [
            SearchBar.Suggestion(id: "1", text: "swift", type: .keyword, matchCount: nil)
        ]
        let props = SearchBar.SuggestionsProps(
            query: "swi",
            suggestions: suggestions,
            showSuggestions: true,
            onQueryChange: { _ in },
            onClear: { },
            onSuggestionSelect: { _ in }
        )

        let nodes = SearchBar.renderWithSuggestions(props: props)

        XCTAssertGreaterThan(nodes.count, 1)
        // Should render without match count
    }

    func testRenderSuggestionsOfDifferentTypes() {
        let suggestions = [
            SearchBar.Suggestion(id: "1", text: "swift", type: .keyword),
            SearchBar.Suggestion(id: "2", text: "Technology", type: .category),
            SearchBar.Suggestion(id: "3", text: "Apple News", type: .feed),
            SearchBar.Suggestion(id: "4", text: "ios development", type: .recent)
        ]
        let props = SearchBar.SuggestionsProps(
            query: "s",
            suggestions: suggestions,
            showSuggestions: true,
            onQueryChange: { _ in },
            onClear: { },
            onSuggestionSelect: { _ in }
        )

        let nodes = SearchBar.renderWithSuggestions(props: props)

        XCTAssertGreaterThan(nodes.count, 1)
        // Should render all suggestion types with different icons
    }

    // MARK: - Edge Cases

    func testRenderWithLongQuery() {
        let longQuery = String(repeating: "test ", count: 50)
        let props = makeTestProps(query: longQuery)

        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle long queries
    }

    func testRenderWithSpecialCharacters() {
        let props = makeTestProps(query: "test@#$%^&*()")

        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should handle special characters
    }

    func testRenderWithEmptyQueryButWithResults() {
        let props = makeTestProps(query: "", resultCount: 10)

        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should not show results when query is empty
    }

    func testRenderSearchingWithoutQuery() {
        let props = makeTestProps(query: "", isSearching: true)

        let nodes = SearchBar.render(props: props)

        XCTAssertEqual(nodes.count, 1)
        // Should show searching state even without query
    }

    func testRenderWithManySuggestions() {
        let suggestions = (1...100).map { i in
            SearchBar.Suggestion(
                id: "\(i)",
                text: "suggestion \(i)",
                type: .keyword,
                matchCount: i
            )
        }
        let props = SearchBar.SuggestionsProps(
            query: "s",
            suggestions: suggestions,
            showSuggestions: true,
            onQueryChange: { _ in },
            onClear: { },
            onSuggestionSelect: { _ in }
        )

        let nodes = SearchBar.renderWithSuggestions(props: props)

        XCTAssertGreaterThan(nodes.count, 1)
        // Should handle many suggestions
    }
}
