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

        // Detect GPU support
        #if canImport(JavaScriptKit)
        detectGPUSupport()
        #else
        // Non-WASM environment: disable GPU
        GPUComponentConfig.enabled = false
        #endif

        // Load persisted data
        await loadPersistedData()

        // Index articles for search
        await indexArticlesForSearch()

        // Setup reactive effects
        setupReactiveEffects()

        // Mount UI
        #if canImport(JavaScriptKit)
        mountUI()
        #else
        print("✅ Bulletin Board initialized (no UI in non-WASM environment)")
        #endif

        print("✅ Bulletin Board ready!")
    }

    // MARK: - GPU Detection

    #if canImport(JavaScriptKit) && arch(wasm32)
    /// Detects WebGPU support and configures GPU effects accordingly.
    private static func detectGPUSupport() {
        if WebGPUBridge.isSupported() {
            print("✅ WebGPU supported - enabling GPU effects")
            GPUComponentConfig.configureForBalanced()
        } else {
            print("⚠️ WebGPU not supported - using CSS fallback")
            GPUComponentConfig.enabled = false
        }
    }
    #elseif canImport(JavaScriptKit)
    /// Detects WebGPU support (stub for non-WASM JavaScript environments).
    private static func detectGPUSupport() {
        print("ℹ️ Non-WASM environment - disabling GPU effects")
        GPUComponentConfig.enabled = false
    }
    #endif

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

    // MARK: - Reactive State

    /// Signal for article state
    private nonisolated(unsafe) static let articlesSignal = appStore.selectArticles()

    /// Signal for feed state
    private nonisolated(unsafe) static let feedsSignal = appStore.selectFeeds()

    /// Signal for UI state
    private nonisolated(unsafe) static let uiSignal = appStore.selectUI()

    /// Computed signal for filtered articles
    private nonisolated(unsafe) static let filteredArticlesSignal = Computed {
        articlesSignal.get().filteredArticles
    }

    /// Computed signal for article count
    private nonisolated(unsafe) static let articleCountSignal = Computed {
        filteredArticlesSignal.get().count
    }

    /// Computed signal for unread count
    private nonisolated(unsafe) static let unreadCountSignal = Computed {
        articlesSignal.get().unreadCount
    }

    /// Computed signal for feed list
    private nonisolated(unsafe) static let feedListSignal = Computed {
        feedsSignal.get().feeds
    }

    // MARK: - Main View Component

    /// The main application view with reactive effects.
    private static func MainView() -> [AnyNode] {
        // Create reactive view that updates when state changes
        // Effects will automatically re-run when dependencies change

        let header = renderHeader()
        let content = renderContent()
        let footer = renderFooter()

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

    private static func renderHeader() -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
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
                )),
                AnyNode(renderStats())
            ]
        )
    }

    private static func renderStats() -> Element<AnyHTMLContext> {
        // Get reactive values
        let articleCount = articleCountSignal.get()
        let unreadCount = unreadCountSignal.get()
        let feedCount = feedListSignal.get().count

        let statsText = "\(articleCount) articles • \(unreadCount) unread • \(feedCount) feeds"

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "app-stats")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "p",
                    children: [AnyNode(Text(statsText))]
                ))
            ]
        )
    }

    private static func renderContent() -> Element<AnyHTMLContext> {
        // Get current articles from signal
        let articles = filteredArticlesSignal.get()
        let isAnimating = uiSignal.get().isAnimating

        var children: [AnyNode] = []

        if isAnimating {
            // Show loading spinner during animations
            children.append(contentsOf: LoadingSpinner.medium(message: "Loading..."))
        } else if articles.isEmpty {
            // Show empty state
            let emptyState = Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "app-empty")],
                children: [
                    AnyNode(Element<AnyHTMLContext>(
                        tag: "p",
                        children: [AnyNode(Text("No articles yet. Add a feed to get started!"))]
                    ))
                ]
            )
            children.append(AnyNode(emptyState))
        } else {
            // Render article list with GPU effects
            let listProps = ArticleList.Props(
                articles: articles,
                onToggleFavorite: { articleId in
                    appStore.dispatch(ArticleAction.toggleFavorite(id: articleId))
                },
                onMarkAsRead: { articleId in
                    appStore.dispatch(ArticleAction.markAsRead(id: articleId))
                },
                onArticleClick: { articleId in
                    appStore.dispatch(ArticleAction.selectArticle(id: articleId))
                }
            )
            // Use GPU-enhanced variant if enabled
            children.append(contentsOf: ArticleList.renderGPU(props: listProps))
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "app-content")],
            children: children
        )
    }

    private static func renderFooter() -> Element<AnyHTMLContext> {
        Element<AnyHTMLContext>(
            tag: "footer",
            attributes: [Attribute(name: "class", value: "app-footer")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "p",
                    children: [AnyNode(Text("Built with LINKER Framework"))]
                ))
            ]
        )
    }

    // MARK: - Reactive Effects

    /// Sets up reactive effects for the application.
    /// Effects automatically re-run when their dependencies change.
    public static func setupReactiveEffects() {
        // Effect: Auto-index articles when they change
        _ = Effect(execute: {
            let articles = articlesSignal.get().articles
            if !articles.isEmpty {
                Task {
                    await searchService.indexArticles(articles)
                    print("📇 Re-indexed \(articles.count) articles")
                }
            }
        })

        // Effect: Auto-save articles to storage when they change
        _ = Effect(execute: {
            let articles = articlesSignal.get().articles
            if !articles.isEmpty {
                Task {
                    do {
                        try await storageService.saveArticles(articles)
                        print("💾 Saved \(articles.count) articles")
                    } catch {
                        print("⚠️ Failed to save articles: \(error)")
                    }
                }
            }
        })

        // Effect: Auto-save feeds to storage when they change
        _ = Effect(execute: {
            let feeds = feedsSignal.get().feeds
            if !feeds.isEmpty {
                Task {
                    do {
                        try await storageService.saveFeeds(feeds)
                        print("💾 Saved \(feeds.count) feeds")
                    } catch {
                        print("⚠️ Failed to save feeds: \(error)")
                    }
                }
            }
        })

        // Effect: Log state changes (for debugging)
        _ = Effect(execute: {
            let articleCount = articleCountSignal.get()
            let unreadCount = unreadCountSignal.get()
            print("📊 State updated: \(articleCount) articles, \(unreadCount) unread")
        })

        print("⚡ Reactive effects initialized")
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
