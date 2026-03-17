import Foundation
import LINKER
#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

// MARK: - App Log Features

/// Application-specific log features for structured LINKER logging.
public enum AppLogFeature: LogFeature {
    case startup
    case security
    case data
    case nlp
    case ui

    public var name: String {
        switch self {
        case .startup: return "APP.STARTUP"
        case .security: return "APP.SECURITY"
        case .data: return "APP.DATA"
        case .nlp: return "APP.NLP"
        case .ui: return "APP.UI"
        }
    }
    public var parent: LogFeature? { nil }
}

/// Root application component.
///
/// Initializes the Redux store, connects services, loads persisted data,
/// and mounts the main UI to the DOM.
public struct App {

    // MARK: - Services

    private static let feedService = FeedService()
    private static let storageService = StorageService()
    private static let searchService = SearchService()
    private static let nlpService = NLPService()

    // MARK: - Main Entry Point

    public static func main() async {
        // Configure LINKER logging
        await Logger.shared.configureForDevelopment()
        await Logger.shared.info(AppLogFeature.startup, "Bulletin Board starting...")

        // ============================================
        // SECURITY: Enable ALL LINKER security features
        // ============================================
        await Logger.shared.info(AppLogFeature.security, "Enabling security features...")
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
            await Logger.shared.info(AppLogFeature.security, "All security features enabled")
        } catch {
            print("⚠️  Security initialization failed: \(error)")
            print("⚠️  Running with REDUCED security - manual intervention required")
            await Logger.shared.error(AppLogFeature.security, "Security initialization failed: \(error)")
            // Note: App will still function but with reduced security
        }

        // Detect GPU support
        #if canImport(JavaScriptKit)
        await detectGPUSupport()
        #else
        // Non-WASM environment: disable GPU
        GPUComponentConfig.enabled = false
        #endif

        // Configure CORS proxy for cross-origin RSS feed fetching
        // Browser security blocks direct cross-origin requests from WASM
        FeedService.corsProxy = "https://api.codetabs.com/v1/proxy?quest="

        // Load persisted data
        await Logger.shared.info(AppLogFeature.data, "Loading persisted data...")
        await loadPersistedData()

        // Index articles for search
        await Logger.shared.info(AppLogFeature.data, "Indexing articles for search...")
        await indexArticlesForSearch()

        // Process articles with NLP
        await Logger.shared.info(AppLogFeature.nlp, "Processing articles with NLP...")
        await processArticlesWithNLP()

        // Setup reactive effects
        setupReactiveEffects()

        // Mount UI
        await Logger.shared.info(AppLogFeature.ui, "Mounting UI...")
        #if canImport(JavaScriptKit)
        mountUI()
        #else
        print("✅ Bulletin Board initialized (no UI in non-WASM environment)")
        #endif

        await Logger.shared.info(AppLogFeature.startup, "Bulletin Board ready!")
        print("✅ Bulletin Board ready!")
    }

    // MARK: - GPU Detection

    #if canImport(JavaScriptKit) && arch(wasm32)
    /// Detects WebGPU support and configures GPU effects accordingly.
    private static func detectGPUSupport() async {
        let supported = WebGPUBridge.isSupported()
        GPUComponentConfig.enabled = supported
        if supported {
            // Pre-initialize the GPU bridge so it's ready when onMount fires
            await GPUEffectManager.shared.ensureInitialized()
            print("✅ WebGPU supported — GPU effects enabled")
        } else {
            print("ℹ️ WebGPU not supported — using CSS effects (backdrop-filter, box-shadow)")
        }
    }
    #elseif canImport(JavaScriptKit)
    /// Detects WebGPU support (stub for non-WASM JavaScript environments).
    private static func detectGPUSupport() async {
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

    /// Processes unprocessed articles through the NLP pipeline.
    private static func processArticlesWithNLP() async {
        let articles = appStore.getState().articles.articles
        let unprocessed = articles.filter { !$0.isNLPProcessed }
        guard !unprocessed.isEmpty else { return }

        print("🧠 Processing \(unprocessed.count) articles with NLP...")

        await nlpService.buildCorpus(from: articles)
        let results = await nlpService.processArticles(unprocessed)

        let updates = results.map { result in
            (id: result.articleId,
             summary: result.summary,
             keywords: result.keywords,
             category: result.category,
             sentiment: nil as Double?,
             cluster: nil as Int?)
        }
        appStore.dispatch(ArticleAction.batchUpdateNLP(updates))
        print("  ✓ NLP processing complete for \(results.count) articles")
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

        // Initialize DOM reconciler
        let bridge = DOMBridge()
        reconciler = DOMReconciler(bridge: bridge)
        reconciler?.mount(rootElement: rootElement)

        // Initial render
        renderToDOM()

        // Set up reactive rendering - re-render on state changes
        // Debounced to avoid excessive patching
        var renderScheduled = false
        _ = appStore.subscribe { _ in
            guard !renderScheduled else { return }
            renderScheduled = true
            // Batch updates in next microtask
            _ = SafeJSGlobal.global?.queueMicrotask.function?(JSClosure { _ in
                renderScheduled = false
                renderToDOM()
                return .undefined
            })
        }

        // Set up event handlers after initial render
        setupEventHandlers(document: document)

        print("✅ UI mounted successfully")
    }

    /// The DOM reconciler instance
    private nonisolated(unsafe) static var reconciler: DOMReconciler?

    /// Renders the main view to the DOM using reconciliation
    private static func renderToDOM() {
        let nodes = MainView()
        reconciler?.update(newTree: nodes)
    }

    /// Sets up all event listeners for user interactions
    private static func setupEventHandlers(document: JSObject) {
        setupClickHandler(document: document)
        setupSubmitHandler(document: document)
        setupSearchHandlers(document: document)
        setupDragHandler(document: document)
        print("⚡ Event handlers registered")
    }

    // MARK: - Unified Click Handler

    /// Single click handler for ALL actions (avoids competing listeners)
    private static func setupClickHandler(document: JSObject) {
        let clickHandler = JSClosure { args -> JSValue in
            guard args.count > 0,
                  let event = args[0].object,
                  let target = event.target.object else {
                return JSValue.undefined
            }

            // Walk up the DOM tree to find the nearest element with data-action
            guard let actionEl = target.closest!("[data-action]").object,
                  let action = actionEl.dataset.object?["action"].string else {
                return JSValue.undefined
            }

            switch action {
            // -- Tab navigation --
            case "switch-tab":
                if let tab = actionEl.dataset.object?["tab"].string {
                    appStore.dispatch(UIAction.switchTab(tab))
                }

            // -- Toolbar / global actions --
            case "open-feed-manager":
                appStore.dispatch(UIAction.openFeedManager)

            case "close-feed-manager-overlay":
                // Only close if clicking directly on the overlay background,
                // not on content that bubbled up to the overlay.
                // Check: target's own data-action must be "close-feed-manager-overlay"
                if target.dataset.object?["action"].string == "close-feed-manager-overlay" {
                    appStore.dispatch(UIAction.closeFeedManager)
                }

            case "close-feed-manager", "close":
                appStore.dispatch(UIAction.closeFeedManager)

            case "refresh-all":
                Task { await refreshAllFeeds() }

            case "dismiss-toast":
                appStore.dispatch(UIAction.clearToast)

            case "clear-search":
                appStore.dispatch(ArticleAction.setSearchQuery(""))

            // -- Feed-specific actions (need data-feed-id from item or button) --
            case "toggle", "refresh", "edit", "delete":
                // data-feed-id may be on the button itself or on a parent feed-item wrapper
                let feedId = actionEl.dataset.object?["feedId"].string
                    ?? target.closest!("[data-feed-id]").object?.dataset.object?["feedId"].string
                if let feedId = feedId {
                    handleFeedAction(action: action, feedId: feedId)
                }

            // -- Article actions (need data-article-id from parent) --
            case "toggle-favorite", "mark-read", "article-click":
                if let articleEl = target.closest!("[data-article-id]").object,
                   let articleId = articleEl.dataset.object?["articleId"].string {
                    switch action {
                    case "toggle-favorite":
                        appStore.dispatch(ArticleAction.toggleFavorite(id: articleId))
                    case "mark-read":
                        appStore.dispatch(ArticleAction.markAsRead(id: articleId))
                    case "article-click":
                        appStore.dispatch(UIAction.expandArticle(id: articleId))
                    default:
                        break
                    }
                }

            default:
                break
            }

            return JSValue.undefined
        }

        document.addEventListener!("click", clickHandler)
    }

    // MARK: - Form Submit Handler

    private static func setupSubmitHandler(document: JSObject) {
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

            // Get feed URL
            guard let urlInput = document.getElementById!("feed-url").object,
                  let url = urlInput.value.string,
                  !url.isEmpty else {
                print("❌ Feed URL input not found or empty")
                return JSValue.undefined
            }

            // Clear input
            urlInput.value = .string("")

            // Dispatch add feed action
            Task {
                await addFeedHelper(url: url)
            }

            return JSValue.undefined
        }

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
            showToast("Feed removed")

        default:
            break
        }
    }

    /// Refresh all feeds
    private static func refreshAllFeeds() async {
        let feedsState = appStore.getState().feeds

        showToast("Refreshing all feeds...")

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

        showToast("Refreshed \(totalArticles) articles from \(feedsState.feeds.count) feeds")
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

            // Check if this is the search input by id
            let targetId = target.id.string ?? ""
            let isSearch = targetId == "search-input"

            guard isSearch else {
                return JSValue.undefined
            }

            let query = target.value.string ?? ""

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

    // MARK: - Drag Handler

    /// Set up draggable image handler
    private static func setupDragHandler(document: JSObject) {
        let global = JSObject.global

        // Drag state (mutable across closures via UnsafeSendableBox)
        var isDragging = false
        var startX = 0.0
        var startY = 0.0
        var initialLeft = 0.0
        var initialTop = 0.0

        let mouseDownHandler = JSClosure { args -> JSValue in
            guard args.count > 0,
                  let event = args[0].object,
                  let target = event.target.object else {
                return JSValue.undefined
            }

            // Check if this is the draggable image container
            let targetId = target.id.string ?? ""
            let container = targetId == "draggable-image-container"
                ? target
                : target.closest!("#draggable-image-container").object

            guard let container = container else {
                return JSValue.undefined
            }

            isDragging = true
            startX = event.clientX.number ?? 0.0
            startY = event.clientY.number ?? 0.0

            let computedStyle = global.getComputedStyle!(container)
            initialLeft = Double(computedStyle.left.string?.replacingOccurrences(of: "px", with: "") ?? "0") ?? 0.0
            initialTop = Double(computedStyle.top.string?.replacingOccurrences(of: "px", with: "") ?? "0") ?? 0.0

            event.preventDefault!()
            return JSValue.undefined
        }

        let mouseMoveHandler = JSClosure { args -> JSValue in
            guard isDragging,
                  args.count > 0,
                  let event = args[0].object else {
                return JSValue.undefined
            }

            let currentX = event.clientX.number ?? 0.0
            let currentY = event.clientY.number ?? 0.0

            let deltaX = currentX - startX
            let deltaY = currentY - startY

            let newLeft = initialLeft + deltaX
            let newTop = initialTop + deltaY

            if let container = document.getElementById!("draggable-image-container").object {
                container.style.object?.setProperty!("left", "\(newLeft)px")
                container.style.object?.setProperty!("top", "\(newTop)px")
            }

            return JSValue.undefined
        }

        let mouseUpHandler = JSClosure { _ -> JSValue in
            isDragging = false
            return JSValue.undefined
        }

        document.addEventListener!("mousedown", mouseDownHandler)
        document.addEventListener!("mousemove", mouseMoveHandler)
        document.addEventListener!("mouseup", mouseUpHandler)
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

        // Tab navigation
        children.append(contentsOf: renderTabNav())

        // Active tab content
        let activeTab = uiSignal.get().activeTab
        if activeTab == "webgpu-test" {
            children.append(contentsOf: renderWebGPUTestTab())
        } else {
            // Original news feed UI
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
        }

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

    // MARK: - Tab Navigation

    private static func renderTabNav() -> [AnyNode] {
        let activeTab = uiSignal.get().activeTab

        let webgpuTabClass = activeTab == "webgpu-test" ? "tab-button tab-button--active" : "tab-button"
        let newsFeedTabClass = activeTab == "news-feed" ? "tab-button tab-button--active" : "tab-button"

        return [
            AnyNode(Element<AnyHTMLContext>(
                tag: "nav",
                attributes: [Attribute(name: "class", value: "tab-nav")],
                children: [
                    AnyNode(Element<AnyHTMLContext>(
                        tag: "button",
                        attributes: [
                            Attribute(name: "type", value: "button"),
                            Attribute(name: "class", value: webgpuTabClass),
                            Attribute(name: "data-action", value: "switch-tab"),
                            Attribute(name: "data-tab", value: "webgpu-test")
                        ],
                        children: [AnyNode(Text("WebGPU Test Grid"))]
                    )),
                    AnyNode(Element<AnyHTMLContext>(
                        tag: "button",
                        attributes: [
                            Attribute(name: "type", value: "button"),
                            Attribute(name: "class", value: newsFeedTabClass),
                            Attribute(name: "data-action", value: "switch-tab"),
                            Attribute(name: "data-tab", value: "news-feed")
                        ],
                        children: [AnyNode(Text("News Feed"))]
                    ))
                ]
            ))
        ]
    }

    // MARK: - WebGPU Test Tab

    private static func renderWebGPUTestTab() -> [AnyNode] {
        var children: [AnyNode] = []

        // Shadow test view above grid
        children.append(contentsOf: renderShadowTestView())

        // 5x5 grid of random WebGPU effects
        children.append(AnyNode(renderWebGPUGrid()))

        // Draggable image for testing
        children.append(contentsOf: renderDraggableImage())

        return children
    }

    private static func renderShadowTestView() -> [AnyNode] {
        // High elevation shadow view to test shadow effects - MOUSE REACTIVE
        // Note: ShadowView sizes its canvas to its container, so the container
        // must be the same size as the visible content for proper shadow alignment.
        return [AnyNode(Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "style", value: "padding: 2rem; max-width: 600px; margin: 2rem auto;")
            ],
            children: ShadowView(style: .elevation16, mouseReactive: true) {
                return [AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [
                        Attribute(name: "class", value: "shadow-test-box"),
                        Attribute(name: "style", value: "padding: 2rem; background: white; border-radius: 8px;")
                    ],
                    children: [
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "h2",
                            children: [AnyNode(Text("Shadow Test - Elevation 16 🖱️"))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "p",
                            children: [AnyNode(Text("This box has a mouse-reactive shadow rendered by WebGPU. Move your mouse around the page and watch the shadow direction change based on your cursor position!"))]
                        ))
                    ]
                ))]
            }
        ))]
    }

    private static func renderWebGPUGrid() -> Element<AnyHTMLContext> {
        var gridCells: [AnyNode] = []

        // Create 5x5 grid (25 cells) with random WebGPU effects
        for row in 0..<5 {
            for col in 0..<5 {
                let cellIndex = row * 5 + col
                gridCells.append(AnyNode(renderGridCell(index: cellIndex, row: row, col: col)))
            }
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "webgpu-grid"),
                Attribute(name: "style", value: "display: grid; grid-template-columns: repeat(5, 1fr); gap: 1rem; padding: 2rem; max-width: 1200px; margin: 0 auto;")
            ],
            children: gridCells
        )
    }

    private static func renderGridCell(index: Int, row: Int, col: Int) -> Element<AnyHTMLContext> {
        // Randomly select effect type based on cell index
        let effectType = index % 4

        let cellContent: [AnyNode]
        let cellLabel: String
        let cellBackground: String

        // Diverse gradients for blur testing
        let gradients = [
            "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
            "linear-gradient(135deg, #f093fb 0%, #f5576c 100%)",
            "linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)",
            "linear-gradient(135deg, #43e97b 0%, #38f9d7 100%)",
            "linear-gradient(135deg, #fa709a 0%, #fee140 100%)",
            "linear-gradient(135deg, #30cfd0 0%, #330867 100%)",
            "linear-gradient(135deg, #a8edea 0%, #fed6e3 100%)",
            "linear-gradient(135deg, #ff9a56 0%, #ff6a88 100%)"
        ]

        let gradientIndex = (row * 5 + col) % gradients.count
        let background = gradients[gradientIndex]

        switch effectType {
        case 0:
            // BlurView with systemMaterial — transparent cell so backdrop-filter blurs page content behind
            cellLabel = "Blur: System"
            cellBackground = "transparent"
            cellContent = BlurView(style: .systemMaterial, intensity: 1.0) {
                return [AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "style", value: "padding: 1rem; color: white; font-weight: bold; text-align: center; text-shadow: 0 2px 4px rgba(0,0,0,0.3); min-height: 100px; display: flex; align-items: center; justify-content: center;")],
                    children: [AnyNode(Text("Cell \(index)\n\(cellLabel)"))]
                ))]
            }
        case 1:
            // BlurView with frostedGlass — transparent cell so backdrop-filter blurs page content behind
            cellLabel = "Blur: Frosted"
            cellBackground = "transparent"
            cellContent = BlurView(style: .frostedGlass, intensity: 1.0) {
                return [AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "style", value: "padding: 1rem; color: white; font-weight: bold; text-align: center; text-shadow: 0 2px 4px rgba(0,0,0,0.3); min-height: 100px; display: flex; align-items: center; justify-content: center;")],
                    children: [AnyNode(Text("Cell \(index)\n\(cellLabel)"))]
                ))]
            }
        case 2:
            // ShadowView with varying elevations — transparent cell, colorful card inside
            let elevation: ShadowStyle = [.elevation1, .elevation2, .elevation4, .elevation8].randomElement()!
            cellLabel = "Shadow: \(elevation)"
            cellBackground = "transparent"
            cellContent = ShadowView(style: elevation, mouseReactive: true) {
                return [AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "style", value: "padding: 1rem; background: \(background); border-radius: 8px; text-align: center; min-height: 80px; display: flex; align-items: center; justify-content: center; color: white; font-weight: bold; text-shadow: 0 1px 3px rgba(0,0,0,0.3);")],
                    children: [AnyNode(Text("Cell \(index)\n\(cellLabel)\n🖱️ REACTIVE"))]
                ))]
            }
        default:
            // Combined BlurView + ShadowView — transparent cell for blur, shadow inside
            cellLabel = "Blur+Shadow"
            cellBackground = "transparent"
            cellContent = BlurView(style: .frostedGlass, intensity: 1.0) {
                return ShadowView(style: .elevation4, mouseReactive: true) {
                    return [AnyNode(Element<AnyHTMLContext>(
                        tag: "div",
                        attributes: [Attribute(name: "style", value: "padding: 1rem; color: white; font-weight: bold; text-align: center; text-shadow: 0 2px 4px rgba(0,0,0,0.3); min-height: 100px; display: flex; align-items: center; justify-content: center;")],
                        children: [AnyNode(Text("Cell \(index)\n\(cellLabel)\n🖱️ REACTIVE"))]
                    ))]
                }
            }
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "grid-cell"),
                Attribute(name: "style", value: "min-height: 120px; background: \(cellBackground); border-radius: 8px; position: relative; overflow: visible;")
            ],
            children: cellContent
        )
    }

    private static func renderDraggableImage() -> [AnyNode] {
        // Real photo from picsum.photos (CORS-safe, no auth needed)
        let imageUrl = "https://picsum.photos/id/29/400/300"

        return [
            AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [
                    Attribute(name: "id", value: "draggable-image-container"),
                    Attribute(name: "style", value: "position: fixed; left: 50px; top: 300px; cursor: move; z-index: 0; pointer-events: auto;")
                ],
                children: [
                    AnyNode(Element<AnyHTMLContext>(
                        tag: "img",
                        attributes: [
                            Attribute(name: "id", value: "draggable-image"),
                            Attribute(name: "src", value: imageUrl),
                            Attribute(name: "alt", value: "Draggable test image"),
                            Attribute(name: "crossorigin", value: "anonymous"),
                            Attribute(name: "draggable", value: "false"),
                            Attribute(name: "style", value: "width: 400px; height: 300px; border: 3px solid white; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.3); user-select: none; object-fit: cover;")
                        ]
                    ))
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
                Task {
                    if let feed = feedsState.feeds.first(where: { $0.id == feedId }) {
                        await refreshFeed(feed: feed)
                    }
                }
            },
            onChangeMode: { _ in },
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
            showToast("Feed refreshed: \(feed.title)")
        } catch {
            appStore.dispatch(UIAction.showError("Failed to refresh: \(error.localizedDescription)"))
        }
    }

    /// Helper: Add feed from URL
    private static func addFeedHelper(url: String) async {
        showToast("Fetching feed...")

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
            showToast("Feed added with \(articles.count) articles")

            print("✅ Feed added: \(url) with \(articles.count) articles")
        } catch let error as FeedService.FeedError {
            let message: String
            switch error {
            case .invalidURL:
                message = "Invalid URL. Please enter a valid feed address."
            case .corsBlocked(let detail):
                message = detail
            case .parseError(let detail):
                message = "Not a valid RSS/Atom feed: \(detail)"
            case .noItems:
                message = "Feed has no articles. Check the URL and try again."
            case .networkError(let detail):
                message = "Network error: \(detail)"
            case .rateLimitExceeded:
                message = "Too many requests. Please wait a moment and try again."
            }
            appStore.dispatch(UIAction.showError(message))
            print("❌ Failed to add feed: \(error)")
        } catch {
            appStore.dispatch(UIAction.showError("Failed to add feed: \(error.localizedDescription)"))
            print("❌ Failed to add feed: \(error)")
        }
    }

    /// Shows a toast that auto-dismisses after a delay
    private static func showToast(_ message: String, duration: UInt64 = 3_000_000_000) {
        appStore.dispatch(UIAction.showToast(message))
        Task {
            try? await Task.sleep(nanoseconds: duration)
            // Only dismiss if the toast message hasn't changed
            if appStore.getState().ui.toastMessage == message {
                appStore.dispatch(UIAction.clearToast)
            }
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

        // Effect: Auto-process new articles with NLP
        _ = Effect(execute: {
            let articles = articlesSignal.get().articles
            let unprocessed = articles.filter { !$0.isNLPProcessed }
            if !unprocessed.isEmpty {
                Task { await processArticlesWithNLP() }
            }
        })

        print("⚡ Reactive effects initialized")
    }

    // MARK: - Public API

    /// Provides access to services for components.
    public static var services: Services {
        Services(
            feed: feedService,
            storage: storageService,
            search: searchService,
            nlp: nlpService
        )
    }

    /// Container for app services.
    public struct Services {
        public let feed: FeedService
        public let storage: StorageService
        public let search: SearchService
        public let nlp: NLPService
    }
}
