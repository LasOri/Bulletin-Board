import Foundation
import LINKER
#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

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

        // ============================================
        // SECURITY: Enable ALL LINKER security features
        // ============================================
        do {
            try await LINKERSecurity.enableAllSecurity(
                htmlPolicy: .moderate,              // Allow some HTML formatting in feeds
                csrfTokenLifetime: 3600,            // 1 hour CSRF token lifetime
                rateLimitCapacity: 100,             // 100 requests burst capacity
                rateLimitRefillRate: 10,            // 10 requests/second sustained rate
                enforceHTTPS: true,                 // Only HTTPS for external RSS feeds
                allowedHosts: nil,                  // Allow all hosts (RSS feeds are external)
                enableWebAuthn: true,               // Hardware-backed encryption (TouchID/YubiKey)
                webAuthnRpId: "bulletin-board.app"  // Relying party ID
            )

            // Print security status
            let status = LINKERSecurity.getSecurityStatus()
            status.printStatus()

            // Apply Content Security Policy
            #if canImport(JavaScriptKit) && arch(wasm32)
            CSPConfiguration.apply()
            #endif

            print("🛡️  All LINKER security features ENABLED:")
            print("   ✅ HTML Sanitization (XSS protection)")
            print("   ✅ CSRF Protection (state-modifying actions)")
            print("   ✅ Rate Limiting (abuse prevention)")
            print("   ✅ HTTPS Enforcement (secure connections)")
            print("   ✅ WebAuthn Hardware-Backed Encryption")
            print("   ✅ Content Security Policy")
        } catch {
            print("⚠️  Security initialization failed: \(error)")
            print("⚠️  Running with REDUCED security - manual intervention required")
            // Note: App will still function but with reduced security
        }

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

    #if canImport(JavaScriptKit) && arch(wasm32)
    /// Mounts the UI to the DOM.
    private static func mountUI() {
        print("🎨 Mounting UI...")

        guard let document = SafeJSGlobal.global?.document.object else {
            print("❌ Failed to access document")
            return
        }

        // Get root element
        guard let rootElement = document.getElementById!("app").object else {
            print("❌ Root element #app not found")
            return
        }

        // Initial render
        renderToDOM(rootElement: rootElement)

        // Set up reactive rendering - re-render on state changes
        _ = appStore.subscribe { _ in
            Task {
                renderToDOM(rootElement: rootElement)
            }
        }

        // Set up event handlers after initial render
        setupEventHandlers(document: document)

        print("✅ UI mounted successfully")
    }

    /// Renders the main view to the DOM
    private static func renderToDOM(rootElement: JSObject) {
        let nodes = MainView()
        let html = nodesToHTML(nodes)
        rootElement.innerHTML = JSValue.string(html)
    }

    /// Converts AnyNode array to HTML string
    private static func nodesToHTML(_ nodes: [AnyNode]) -> String {
        return nodes.map { node in
            // Use AnyNode's render method
            return node.render()
        }.joined()
    }

    /// Sets up all event listeners for user interactions
    private static func setupEventHandlers(document: JSObject) {
        setupArticleHandlers(document: document)
        setupFeedManagerHandlers(document: document)
        setupSearchHandlers(document: document)
        print("⚡ Event handlers registered")
    }

    // MARK: - Article Event Handlers

    /// Set up article card event listeners
    private static func setupArticleHandlers(document: JSObject) {
        // Use event delegation on document for all article interactions
        let clickHandler = JSClosure { args -> JSValue in
            guard args.count > 0,
                  let event = args[0].object,
                  let target = event.target.object else {
                return JSValue.undefined
            }

            // Check for data-action attribute
            guard let datasetObj = target.dataset.object,
                  let action = datasetObj["action"].string else {
                return JSValue.undefined
            }

            // Get article ID
            guard let articleId = datasetObj["articleId"].string else {
                return JSValue.undefined
            }

            // Dispatch appropriate action
            switch action {
            case "toggle-favorite":
                appStore.dispatch(ArticleAction.toggleFavorite(id: articleId))
            case "mark-read":
                appStore.dispatch(ArticleAction.markAsRead(id: articleId))
            case "article-click":
                appStore.dispatch(UIAction.toggleArticleExpand(id: articleId))
            default:
                break
            }

            return JSValue.undefined
        }

        document.addEventListener!("click", clickHandler)
    }

    // MARK: - Feed Manager Event Handlers

    /// Set up feed manager event listeners
    private static func setupFeedManagerHandlers(document: JSObject) {
        // Click handler for buttons
        let clickHandler = JSClosure { args -> JSValue in
            guard args.count > 0,
                  let event = args[0].object,
                  let target = event.target.object else {
                return JSValue.undefined
            }

            guard let action = target.dataset.object?["action"].string else {
                return JSValue.undefined
            }

            switch action {
            case "open-feed-manager":
                appStore.dispatch(UIAction.openFeedManager)
            case "close-feed-manager", "close-feed-manager-overlay":
                appStore.dispatch(UIAction.closeFeedManager)
            case "refresh-all":
                Task {
                    await refreshAllFeeds()
                }
            case "dismiss-toast":
                appStore.dispatch(UIAction.clearToast)
            case "clear-search":
                appStore.dispatch(ArticleAction.setSearchQuery(""))
            case "show-add-form":
                // Switch to add feed mode
                print("Show add feed form")
            case "show-list":
                // Switch back to list mode
                print("Show feed list")
            case "toggle", "refresh", "edit", "delete":
                // Feed-specific actions
                if let feedId = target.dataset.object?["feedId"].string {
                    handleFeedAction(action: action, feedId: feedId)
                }
            default:
                break
            }

            return JSValue.undefined
        }

        // Form submission handler
        let submitHandler = JSClosure { args -> JSValue in
            guard args.count > 0,
                  let event = args[0].object,
                  let form = event.target.object else {
                return JSValue.undefined
            }

            // Prevent default form submission
            _ = event.preventDefault!()

            // Check if this is the add feed form
            guard let formAction = form.dataset.object?["form"].string,
                  formAction == "add-feed" else {
                return JSValue.undefined
            }

            // Get form values
            guard let urlInput = document.getElementById!("feed-url").object,
                  let url = urlInput.value.string else {
                print("❌ Feed URL input not found")
                return JSValue.undefined
            }

            // Validate CSRF token
            guard let csrfInput = form.querySelector!("[name='csrf_token']").object,
                  let csrfToken = csrfInput.value.string,
                  SecurityManager.shared.csrfManager.validateToken(csrfToken) else {
                print("❌ CSRF token validation failed")
                appStore.dispatch(UIAction.showError("Security validation failed"))
                return JSValue.undefined
            }

            // Dispatch add feed action
            Task {
                await addFeedHelper(url: url)
            }

            return JSValue.undefined
        }

        document.addEventListener!("click", clickHandler)
        document.addEventListener!("submit", submitHandler)
    }

    /// Handle feed-specific actions
    private static func handleFeedAction(action: String, feedId: String) {
        let feedsState = appStore.getState().feeds

        guard let feed = feedsState.feeds.first(where: { $0.id == feedId }) else {
            return
        }

        switch action {
        case "toggle":
            var updated = feed
            updated.isEnabled = !updated.isEnabled
            appStore.dispatch(FeedAction.updateFeed(id: feedId, updated))

        case "refresh":
            Task {
                await refreshFeed(feed: feed)
            }

        case "edit":
            print("Edit feed: \(feedId)")
            // Future: Switch to edit mode

        case "delete":
            appStore.dispatch(FeedAction.removeFeed(id: feedId))
            appStore.dispatch(UIAction.showToast("Feed removed"))

        default:
            break
        }
    }

    /// Refresh all feeds
    private static func refreshAllFeeds() async {
        let feedsState = appStore.getState().feeds

        appStore.dispatch(UIAction.showToast("Refreshing all feeds..."))

        var totalArticles = 0

        for feed in feedsState.feeds where feed.isEnabled {
            do {
                let articles = try await feedService.fetchFeed(from: feed.url, feedId: feed.id)
                appStore.dispatch(ArticleAction.addArticles(articles))
                totalArticles += articles.count
            } catch {
                print("❌ Failed to refresh \(feed.title): \(error)")
            }
        }

        appStore.dispatch(UIAction.showToast("Refreshed \(totalArticles) articles from \(feedsState.feeds.count) feeds"))
    }

    // MARK: - Search Event Handlers

    /// Set up search bar event listeners
    private static func setupSearchHandlers(document: JSObject) {
        // Debounced search input
        var searchTask: Task<Void, Never>?

        let inputHandler = JSClosure { args -> JSValue in
            guard args.count > 0,
                  let event = args[0].object,
                  let target = event.target.object else {
                return JSValue.undefined
            }

            // Check if this is the search input (using data-search-input attribute)
            guard let datasetObj = target.dataset.object,
                  let isSearchInput = datasetObj["searchInput"].string,
                  isSearchInput == "true",
                  let query = target.value.string else {
                return JSValue.undefined
            }

            // Cancel previous search task
            searchTask?.cancel()

            // Debounce search (300ms)
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !Task.isCancelled {
                    appStore.dispatch(ArticleAction.setSearchQuery(query))
                }
            }

            return JSValue.undefined
        }

        document.addEventListener!("input", inputHandler)
    }
    #elseif canImport(JavaScriptKit)
    /// Mounts the UI to the DOM (stub for non-WASM JavaScriptKit environments).
    private static func mountUI() {
        print("🎨 Mounting UI...")
        print("  ℹ️ DOM mounting only available in WASM environment")
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

        var children: [AnyNode] = []

        // Main app container
        let header = renderHeader()
        let searchBar = renderSearchBar()
        let toolbar = renderToolbar()
        let content = renderContent()
        let footer = renderFooter()

        children.append(AnyNode(header))
        children.append(contentsOf: searchBar)
        children.append(contentsOf: toolbar)
        children.append(AnyNode(content))
        children.append(AnyNode(footer))

        // Overlays (conditionally rendered)
        children.append(contentsOf: renderFeedManager())
        children.append(contentsOf: renderToast())
        children.append(contentsOf: renderErrorMessage())

        return [
            AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "bulletin-board-app")],
                children: children
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

    // MARK: - New UI Components

    /// Render search bar
    private static func renderSearchBar() -> [AnyNode] {
        let articlesState = articlesSignal.get()
        let searchQuery = articlesState.searchQuery

        let props = SearchBar.Props(
            query: searchQuery,
            placeholder: "Search articles...",
            isSearching: false,
            resultCount: articlesState.filteredArticles.count,
            onQueryChange: { query in
                appStore.dispatch(ArticleAction.setSearchQuery(query))
            },
            onClear: {
                appStore.dispatch(ArticleAction.setSearchQuery(""))
            }
        )

        return SearchBar.render(props: props)
    }

    /// Render toolbar with action buttons
    private static func renderToolbar() -> [AnyNode] {
        let toolbar = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "app-toolbar")],
            children: [
                // Add Feed button
                AnyNode(Element<AnyHTMLContext>(
                    tag: "button",
                    attributes: [
                        Attribute(name: "type", value: "button"),
                        Attribute(name: "class", value: "toolbar-button toolbar-button--primary"),
                        Attribute(name: "data-action", value: "open-feed-manager"),
                        Attribute(name: "aria-label", value: "Add new feed")
                    ],
                    children: [AnyNode(Text("➕ Add Feed"))]
                )),
                // Refresh All button
                AnyNode(Element<AnyHTMLContext>(
                    tag: "button",
                    attributes: [
                        Attribute(name: "type", value: "button"),
                        Attribute(name: "class", value: "toolbar-button"),
                        Attribute(name: "data-action", value: "refresh-all"),
                        Attribute(name: "aria-label", value: "Refresh all feeds")
                    ],
                    children: [AnyNode(Text("🔄 Refresh All"))]
                ))
            ]
        )

        return [AnyNode(toolbar)]
    }

    /// Render feed manager modal (conditionally)
    private static func renderFeedManager() -> [AnyNode] {
        let uiState = uiSignal.get()

        // Only render if feed manager is open
        guard uiState.isFeedManagerOpen else {
            return []
        }

        let feedsState = feedsSignal.get()

        let props = FeedManager.Props(
            feeds: feedsState.feeds,
            viewMode: .list,
            isLoading: false,
            error: nil,
            onAddFeed: { url in
                Task {
                    await addFeedHelper(url: url)
                }
            },
            onEditFeed: { feed in
                appStore.dispatch(FeedAction.updateFeed(id: feed.id, feed))
            },
            onDeleteFeed: { feedId in
                appStore.dispatch(FeedAction.removeFeed(id: feedId))
            },
            onToggleFeed: { feedId in
                appStore.dispatch(FeedAction.toggleFeedEnabled(id: feedId))
            },
            onRefreshFeed: { feedId in
                // Refresh specific feed
                Task {
                    if let feed = feedsState.feeds.first(where: { $0.id == feedId }) {
                        await refreshFeed(feed: feed)
                    }
                }
            },
            onChangeMode: { _ in
                // Mode changes handled by event handlers
            },
            onClose: {
                appStore.dispatch(UIAction.closeFeedManager)
            }
        )

        // Wrap in modal overlay
        let modal = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "modal-overlay"),
                Attribute(name: "data-action", value: "close-feed-manager-overlay")
            ],
            children: FeedManager.renderGPU(props: props)
        )

        return [AnyNode(modal)]
    }

    /// Render toast notification (conditionally)
    private static func renderToast() -> [AnyNode] {
        let uiState = uiSignal.get()

        guard let message = uiState.toastMessage else {
            return []
        }

        let toast = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "toast toast--success"),
                Attribute(name: "role", value: "status"),
                Attribute(name: "aria-live", value: "polite")
            ],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "span",
                    attributes: [Attribute(name: "class", value: "toast__message")],
                    children: [AnyNode(Text(message))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "button",
                    attributes: [
                        Attribute(name: "type", value: "button"),
                        Attribute(name: "class", value: "toast__close"),
                        Attribute(name: "aria-label", value: "Dismiss"),
                        Attribute(name: "data-action", value: "dismiss-toast")
                    ],
                    children: [AnyNode(Text("✕"))]
                ))
            ]
        )

        return [AnyNode(toast)]
    }

    /// Render error message (conditionally)
    private static func renderErrorMessage() -> [AnyNode] {
        let uiState = uiSignal.get()

        guard let errorMsg = uiState.errorMessage else {
            return []
        }

        return ErrorMessage.error(
            message: errorMsg,
            onDismiss: {
                appStore.dispatch(UIAction.clearError)
            }
        )
    }

    /// Helper: Refresh a specific feed
    private static func refreshFeed(feed: Feed) async {
        do {
            // Note: UIState.isAnimating is automatically managed by animation actions
            let articles = try await feedService.fetchFeed(from: feed.url, feedId: feed.id)
            appStore.dispatch(ArticleAction.addArticles(articles))
            appStore.dispatch(UIAction.showToast("Feed refreshed: \(feed.title)"))
        } catch {
            appStore.dispatch(UIAction.showError("Failed to refresh: \(error.localizedDescription)"))
        }
    }

    /// Helper: Add feed from URL
    private static func addFeedHelper(url: String) async {
        do {
            let feedId = UUID().uuidString
            let articles = try await feedService.fetchFeed(from: url, feedId: feedId)

            // Add feed to state
            let feed = Feed(id: feedId, title: "New Feed", description: "", url: url)
            appStore.dispatch(FeedAction.addFeed(feed))

            // Add articles
            appStore.dispatch(ArticleAction.addArticles(articles))

            // Success
            appStore.dispatch(UIAction.closeFeedManager)
            appStore.dispatch(UIAction.showToast("Feed added successfully"))

            print("✅ Feed added: \(url) with \(articles.count) articles")
        } catch {
            appStore.dispatch(UIAction.showError("Failed to add feed: \(error.localizedDescription)"))
            print("❌ Failed to add feed: \(error)")
        }
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
