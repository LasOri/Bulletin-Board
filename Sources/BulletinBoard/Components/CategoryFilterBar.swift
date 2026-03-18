import Foundation
import LINKER

/// Horizontal scrollable category filter bar with pill buttons.
public struct CategoryFilterBar {

    public struct Props {
        public let categoryCounts: [(category: ArticleCategory, count: Int)]
        public let activeCategories: Set<ArticleCategory>

        public init(
            categoryCounts: [(category: ArticleCategory, count: Int)],
            activeCategories: Set<ArticleCategory>
        ) {
            self.categoryCounts = categoryCounts
            self.activeCategories = activeCategories
        }
    }

    public static func render(props: Props) -> [AnyNode] {
        guard !props.categoryCounts.isEmpty else { return [] }

        var pills: [AnyNode] = []

        // "All" pill — active when no category filter is set
        let allActive = props.activeCategories.isEmpty
        let allClass = allActive ? "category-pill category-pill--all-active" : "category-pill category-pill--inactive"
        let allPill = Element<AnyHTMLContext>(
            tag: "button",
            attributes: [
                Attribute(name: "type", value: "button"),
                Attribute(name: "class", value: allClass),
                Attribute(name: "data-action", value: "filter-category"),
                Attribute(name: "data-category", value: "all")
            ],
            children: [AnyNode(Text("All"))]
        )
        pills.append(AnyNode(allPill))

        // Category pills
        for item in props.categoryCounts {
            let isActive = props.activeCategories.contains(item.category)
            let pillClass = isActive ? "category-pill category-pill--active" : "category-pill category-pill--inactive"
            let style = isActive
                ? "background-color: \(item.category.color); border-color: \(item.category.color); color: white"
                : "border-color: \(item.category.color); color: \(item.category.color)"

            let pill = Element<AnyHTMLContext>(
                tag: "button",
                attributes: [
                    Attribute(name: "type", value: "button"),
                    Attribute(name: "class", value: pillClass),
                    Attribute(name: "style", value: style),
                    Attribute(name: "data-action", value: "filter-category"),
                    Attribute(name: "data-category", value: item.category.rawValue)
                ],
                children: [AnyNode(Text("\(item.category.rawValue) (\(item.count))"))]
            )
            pills.append(AnyNode(pill))
        }

        let container = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "category-filter-bar")],
            children: pills
        )

        return [AnyNode(container)]
    }
}
