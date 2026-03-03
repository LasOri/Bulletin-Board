import Foundation
import LINKER

/// Root application component.
///
/// Initializes the Redux store, connects services, loads persisted data,
/// and mounts the main UI to the DOM.
public struct App {

    // MARK: - Services

    private static let feedService = FeedService()
    private static let storageService = StorageService()
    private static let searchService = SearchService()

    // MARK: - Main Entry Point

    public static func main() async {
        print("🗞️ Bulletin Board - Starting...")

        // Load persisted data
        await loadPersistedData()

        // Index articles for search
        await indexArticlesForSearch()

        // Mount UI
        #if canImport(JavaScriptKit)
        mountUI()
        #else
        print("✅ Bulletin Board initialized (no UI in non-WASM environment)")
        #endif

        print("✅ Bulletin Board ready!")
    }

    // MARK: - Data Loading

    /// Loads persisted feeds and articles from storage.
    private static func loadPersistedData() async {
        print("📦 Loading persisted data...")

        do {
            // Load feeds
            let feeds = try await storageService.loadFeeds()
            print("  ✓ Loaded \(feeds.count) feeds")

            for feed in feeds {
                appStore.dispatch(FeedAction.addFeed(feed))
            }

            // Load articles
            let articles = try await storageService.loadArticles()
            print("  ✓ Loaded \(articles.count) articles")

            appStore.dispatch(ArticleAction.addArticles(articles))

        } catch StorageService.StorageError.notFound {
            print("  ℹ️ No persisted data found (first run)")

            // Add sample feed for first run
            let sampleFeed = Feed(
                id: "sample-feed",
                title: "Sample RSS Feed",
                description: "Example feed for testing",
                url: "https://example.com/feed.xml"
            )
            appStore.dispatch(FeedAction.addFeed(sampleFeed))

        } catch {
            print("  ⚠️ Error loading data: \(error)")
        }
    }

    /// Indexes all articles in the search service.
    private static func indexArticlesForSearch() async {
        let articles = appStore.getState().articles.articles

        if !articles.isEmpty {
            print("🔍 Indexing \(articles.count) articles for search...")
            await searchService.indexArticles(articles)
            let termCount = await searchService.termCount()
            print("  ✓ Indexed \(termCount) unique terms")
        }
    }

    // MARK: - UI Mounting

    #if canImport(JavaScriptKit)
    /// Mounts the UI to the DOM.
    private static func mountUI() {
        print("🎨 Mounting UI...")
        // TODO: Implement actual DOM mounting when in WASM environment
        // For now, this is a placeholder
        print("  ℹ️ DOM mounting not yet implemented")
    }
    #endif

    // MARK: - Main View Component

    /// The main application view (simplified for initial version).
    private static func MainView() -> [AnyNode] {
        // Simple static view for initial implementation
        // TODO: Add reactive effects once UI is mounted

        let header = Element<AnyHTMLContext>(
            tag: "header",
            attributes: [Attribute(name: "class", value: "app-header")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "h1",
                    children: [AnyNode(Text("🗞️ Bulletin Board"))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "p",
                    children: [AnyNode(Text("Your Personal News Feed Reader"))]
                ))
            ]
        )

        let content = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "app-content")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "p",
                    children: [AnyNode(Text("✅ Application initialized"))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "p",
                    children: [AnyNode(Text("Loading articles..."))]
                ))
            ]
        )

        let footer = Element<AnyHTMLContext>(
            tag: "footer",
            attributes: [Attribute(name: "class", value: "app-footer")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "p",
                    children: [AnyNode(Text("Built with LINKER Framework"))]
                ))
            ]
        )

        return [
            AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "bulletin-board-app")],
                children: [
                    AnyNode(header),
                    AnyNode(content),
                    AnyNode(footer)
                ]
            ))
        ]
    }

    // MARK: - Public API

    /// Provides access to services for components.
    public static var services: Services {
        Services(
            feed: feedService,
            storage: storageService,
            search: searchService
        )
    }

    /// Container for app services.
    public struct Services {
        public let feed: FeedService
        public let storage: StorageService
        public let search: SearchService
    }
}
