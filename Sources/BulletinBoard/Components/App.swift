import Foundation
import LINKER
#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

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

public struct App {

    private static let feedService = FeedService()
    private static let storageService = StorageService()
    private static let searchService = SearchService()
    private static let nlpService = NLPService()

    private static func now() -> Double {
        #if canImport(JavaScriptKit) && arch(wasm32)
        if let perf = SafeJSGlobal.global?.performance.object {
            return perf.now!().number ?? (Date().timeIntervalSince1970 * 1000)
        }
        return Date().timeIntervalSince1970 * 1000
        #else
        return Date().timeIntervalSince1970 * 1000
        #endif
    }

    private static func perf(_ phase: String, since start: Double) -> Double {
        let elapsed = now() - start
        print("[PERF] \(phase): \(String(format: "%.1f", elapsed))ms")
        return now()
    }

    public static func main() async {
        let t0 = now()
        var t = t0

        await Logger.shared.configureForDevelopment()
        t = perf("Logger setup", since: t)
        await Logger.shared.info(AppLogFeature.startup, "Bulletin Board starting...")

        await Logger.shared.info(AppLogFeature.security, "Enabling security features...")
        do {
            try await LINKERSecurity.enableAllSecurity(
                htmlPolicy: .moderate,
                csrfTokenLifetime: 3600,
                rateLimitCapacity: 100,
                rateLimitRefillRate: 10,
                enforceHTTPS: true,
                allowedHosts: nil,
                enableWebAuthn: true,
                webAuthnRpId: "bulletin-board.app"
            )

            let status = LINKERSecurity.getSecurityStatus()
            status.printStatus()

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
        }
        t = perf("Security init", since: t)

        #if canImport(JavaScriptKit)
        await detectGPUSupport()
        #else
        GPUComponentConfig.enabled = false
        #endif
        t = perf("GPU detection + WebGPU init", since: t)

        FeedService.corsProxy = "https://api.codetabs.com/v1/proxy?quest="

        await Logger.shared.info(AppLogFeature.data, "Loading persisted data...")
        await loadPersistedData()
        t = perf("Load persisted data", since: t)

        await Logger.shared.info(AppLogFeature.data, "Indexing articles for search...")
        await indexArticlesForSearch()
        t = perf("Search indexing", since: t)

        await Logger.shared.info(AppLogFeature.nlp, "Processing articles with NLP...")
        await processArticlesWithNLP()
        t = perf("NLP processing", since: t)

        #if canImport(JavaScriptKit) && arch(wasm32)
        await extractDominantColors()
        t = perf("Color extraction", since: t)
        #endif

        setupReactiveEffects()
        t = perf("Reactive effects setup", since: t)

        await Logger.shared.info(AppLogFeature.ui, "Mounting UI...")
        #if canImport(JavaScriptKit)
        mountUI()
        #else
        print("✅ Bulletin Board initialized (no UI in non-WASM environment)")
        #endif
        t = perf("UI mount + initial render", since: t)

        _ = perf("TOTAL Swift startup", since: t0)
        await Logger.shared.info(AppLogFeature.startup, "Bulletin Board ready!")
        print("✅ Bulletin Board ready!")
    }

    #if canImport(JavaScriptKit) && arch(wasm32)
    private static func detectGPUSupport() async {
        let supported = WebGPUBridge.isSupported()
        GPUComponentConfig.enabled = supported
        if supported {
            await GPUEffectManager.shared.ensureInitialized()
            print("✅ WebGPU supported — GPU effects enabled")
        } else {
            print("ℹ️ WebGPU not supported — using CSS effects (backdrop-filter, box-shadow)")
        }
    }
    #elseif canImport(JavaScriptKit)
    private static func detectGPUSupport() async {
        print("ℹ️ Non-WASM environment - disabling GPU effects")
        GPUComponentConfig.enabled = false
    }
    #endif

    private static func loadPersistedData() async {
        print("📦 Loading persisted data...")

        do {
            let feeds = try await storageService.loadFeeds()
            print("  ✓ Loaded \(feeds.count) feeds")

            for feed in feeds {
                appStore.dispatch(FeedAction.addFeed(feed))
            }

            let articles = try await storageService.loadArticles()
            print("  ✓ Loaded \(articles.count) articles")

            appStore.dispatch(ArticleAction.addArticles(articles))

        } catch StorageService.StorageError.notFound {
            print("  ℹ️ No persisted data found (first run)")
        } catch {
            print("  ⚠️ Error loading data: \(error)")
        }
    }

    private static func indexArticlesForSearch() async {
        let articles = appStore.getState().articles.articles

        if !articles.isEmpty {
            print("🔍 Indexing \(articles.count) articles for search...")
            await searchService.indexArticles(articles)
            let termCount = await searchService.termCount()
            print("  ✓ Indexed \(termCount) unique terms")
        }
    }

    private static func processArticlesWithNLP() async {
        let articles = appStore.getState().articles.articles
        let unprocessed = articles.filter { !$0.isNLPProcessed }
        guard !unprocessed.isEmpty else { return }

        print("🧠 Processing \(unprocessed.count) articles with NLP...")

        await nlpService.buildCorpus(from: articles)
        let results = await nlpService.processArticles(unprocessed)

        let allIds = articles.map { $0.id }
        let clusters = await nlpService.clusterArticles(allIds)
        print("  📊 Clustering complete: \(clusters.count) articles assigned to clusters")

        let updates = results.map { result in
            (id: result.articleId,
             summary: result.summary,
             keywords: result.keywords,
             category: result.category,
             sentiment: result.sentimentScore as Double?,
             cluster: clusters[result.articleId] as Int?)
        }
        appStore.dispatch(ArticleAction.batchUpdateNLP(updates))

        let alreadyProcessed = articles.filter { $0.isNLPProcessed }
        if !alreadyProcessed.isEmpty {
            let clusterUpdates = alreadyProcessed.compactMap { article -> (id: String, summary: String?, keywords: [String], category: ArticleCategory?, sentiment: Double?, cluster: Int?)? in
                guard let clusterId = clusters[article.id] else { return nil }
                guard article.clusterId != clusterId else { return nil }
                return (id: article.id,
                        summary: article.nlpSummary,
                        keywords: article.keywords,
                        category: article.autoCategory,
                        sentiment: article.sentimentScore,
                        cluster: clusterId as Int?)
            }
            if !clusterUpdates.isEmpty {
                appStore.dispatch(ArticleAction.batchUpdateNLP(clusterUpdates))
            }
        }

        print("  ✓ NLP processing complete for \(results.count) articles")
    }

    #if canImport(JavaScriptKit) && arch(wasm32)
    private static func extractDominantColors() async {
        let articles = appStore.getState().articles.articles
        let needsColor = articles.filter { article in
            article.dominantColor == nil &&
            article.enclosure?.type.hasPrefix("image/") == true
        }
        guard !needsColor.isEmpty else { return }

        print("🎨 Extracting dominant colors from \(needsColor.count) article images...")

        var updates: [(id: String, color: ArticleColor)] = []

        for article in needsColor {
            guard let imageURL = article.enclosure?.url else { continue }
            if let color = await ColorExtractor.extractDominantColor(from: imageURL) {
                updates.append((id: article.id, color: ArticleColor(r: color.r, g: color.g, b: color.b)))
            }
        }

        if !updates.isEmpty {
            appStore.dispatch(ArticleAction.batchUpdateDominantColors(updates))
            print("  ✓ Extracted colors for \(updates.count) articles")
        }
    }
    #endif

    #if canImport(JavaScriptKit) && arch(wasm32)
    private static func mountUI() {
        print("🎨 Mounting UI...")

        guard let document = SafeJSGlobal.global?.document.object else {
            print("❌ Failed to access document")
            return
        }

        guard let rootElement = document.getElementById!("app").object else {
            print("❌ Root element #app not found")
            return
        }

        let bridge = DOMBridge()
        reconciler = DOMReconciler(bridge: bridge)
        reconciler?.mount(rootElement: rootElement)

        renderToDOM()

        var renderScheduled = false
        _ = appStore.subscribe { _ in
            guard !renderScheduled else { return }
            renderScheduled = true
            _ = SafeJSGlobal.global?.queueMicrotask.function?(JSClosure { _ in
                renderScheduled = false
                renderToDOM()
                return .undefined
            })
        }

        setupEventHandlers(document: document)

        print("✅ UI mounted successfully")
    }

    private nonisolated(unsafe) static var reconciler: DOMReconciler?

    private nonisolated(unsafe) static var renderCount = 0

    private static func renderToDOM() {
        let t0 = now()
        let nodes = MainView()
        let tVdom = now()
        reconciler?.update(newTree: nodes)
        renderCount += 1
        let total = now() - t0
        let vdom = tVdom - t0
        let patch = now() - tVdom
        if renderCount <= 3 || total > 50 {
            print("[PERF] renderToDOM #\(renderCount): \(String(format: "%.1f", total))ms (vdom: \(String(format: "%.1f", vdom))ms, patch: \(String(format: "%.1f", patch))ms)")
        }
    }

    private static func setupEventHandlers(document: JSObject) {
        setupClickHandler(document: document)
        setupSubmitHandler(document: document)
        setupSearchHandlers(document: document)
        CardExpansionController.shared.setupEscapeHandler(document: document)
        print("⚡ Event handlers registered")
    }

    private static func setupClickHandler(document: JSObject) {
        let clickHandler = JSClosure { args -> JSValue in
            guard args.count > 0,
                  let event = args[0].object,
                  let target = event.target.object else {
                return JSValue.undefined
            }

            guard let actionEl = target.closest!("[data-action]").object,
                  let action = actionEl.dataset.object?["action"].string else {
                return JSValue.undefined
            }

            switch action {
            case "open-feed-manager":
                appStore.dispatch(UIAction.openFeedManager)

            case "close-feed-manager-overlay":
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

            case "toggle", "refresh", "edit", "delete":
                let feedId = actionEl.dataset.object?["feedId"].string
                    ?? target.closest!("[data-feed-id]").object?.dataset.object?["feedId"].string
                if let feedId = feedId {
                    handleFeedAction(action: action, feedId: feedId)
                }

            case "filter-category":
                if let categoryStr = actionEl.dataset.object?["category"].string {
                    var currentFilters = appStore.getState().articles.filters
                    if categoryStr == "all" {
                        currentFilters.categories.removeAll()
                    } else if let category = ArticleCategory(rawValue: categoryStr) {
                        if currentFilters.categories.contains(category) {
                            currentFilters.categories.remove(category)
                        } else {
                            currentFilters.categories.insert(category)
                        }
                    }
                    appStore.dispatch(ArticleAction.setFilters(currentFilters))
                    let uiState = uiSignal.get()
                    if uiState.animationPhase == .expanded {
                        CardExpansionController.shared.beginCollapse()
                    }
                }

            case "toggle-favorite", "mark-read", "article-click":
                if let articleEl = target.closest!("[data-article-id]").object,
                   let articleId = articleEl.dataset.object?["articleId"].string {
                    switch action {
                    case "toggle-favorite":
                        appStore.dispatch(ArticleAction.toggleFavorite(id: articleId))
                    case "mark-read":
                        appStore.dispatch(ArticleAction.markAsRead(id: articleId))
                    case "article-click":
                        CardExpansionController.shared.beginExpand(articleId: articleId)
                    default:
                        break
                    }
                }

            case "collapse-article":
                CardExpansionController.shared.beginCollapse()

            case "collapse-article-overlay":
                if target.dataset.object?["action"].string == "collapse-article-overlay" {
                    CardExpansionController.shared.beginCollapse()
                }

            default:
                break
            }

            return JSValue.undefined
        }

        document.addEventListener!("click", clickHandler)
    }

    private static func setupSubmitHandler(document: JSObject) {
        let submitHandler = JSClosure { args -> JSValue in
            guard args.count > 0,
                  let event = args[0].object,
                  let form = event.target.object else {
                return JSValue.undefined
            }

            _ = event.preventDefault!()

            guard let formAction = form.dataset.object?["form"].string,
                  formAction == "add-feed" else {
                return JSValue.undefined
            }

            guard let urlInput = document.getElementById!("feed-url").object,
                  let url = urlInput.value.string,
                  !url.isEmpty else {
                print("❌ Feed URL input not found or empty")
                return JSValue.undefined
            }

            urlInput.value = .string("")

            Task {
                await addFeedHelper(url: url)
            }

            return JSValue.undefined
        }

        document.addEventListener!("submit", submitHandler)
    }

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

        case "delete":
            appStore.dispatch(FeedAction.removeFeed(id: feedId))
            showToast("Feed removed")

        default:
            break
        }
    }

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
        if totalArticles > 0 {
            await processArticlesWithNLP()
            #if canImport(JavaScriptKit) && arch(wasm32)
            await extractDominantColors()
            #endif
        }
    }

    private static func setupSearchHandlers(document: JSObject) {
        var searchTask: Task<Void, Never>?

        let inputHandler = JSClosure { args -> JSValue in
            guard args.count > 0,
                  let event = args[0].object,
                  let target = event.target.object else {
                return JSValue.undefined
            }

            let targetId = target.id.string ?? ""
            let isSearch = targetId == "search-input"

            guard isSearch else {
                return JSValue.undefined
            }

            let query = target.value.string ?? ""

            searchTask?.cancel()

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
    private static func mountUI() {
        print("🎨 Mounting UI...")
        print("  ℹ️ DOM mounting only available in WASM environment")
    }
    #endif

    private nonisolated(unsafe) static let articlesSignal = appStore.selectArticles()

    private nonisolated(unsafe) static let feedsSignal = appStore.selectFeeds()

    private nonisolated(unsafe) static let uiSignal = appStore.selectUI()

    private nonisolated(unsafe) static let filteredArticlesSignal = Computed {
        articlesSignal.get().filteredArticles
    }

    private nonisolated(unsafe) static let articleCountSignal = Computed {
        filteredArticlesSignal.get().count
    }

    private nonisolated(unsafe) static let unreadCountSignal = Computed {
        articlesSignal.get().unreadCount
    }

    private nonisolated(unsafe) static let feedListSignal = Computed {
        feedsSignal.get().feeds
    }

    private static func MainView() -> [AnyNode] {
        var children: [AnyNode] = []

        let header = renderHeader()
        let searchBar = renderSearchBar()
        let toolbar = renderToolbar()
        let content = renderContent()
        let footer = renderFooter()

        children.append(AnyNode(header))
        children.append(contentsOf: searchBar)
        children.append(contentsOf: toolbar)
        children.append(contentsOf: renderCategoryFilterBar())
        children.append(AnyNode(content))
        children.append(AnyNode(footer))

        children.append(contentsOf: renderFeedManager())
        children.append(contentsOf: renderArticleDetail())
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
        let articles = filteredArticlesSignal.get()

        var children: [AnyNode] = []

        if articles.isEmpty {
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

    private static func renderToolbar() -> [AnyNode] {
        let toolbar = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "app-toolbar")],
            children: [
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

    private static func renderCategoryFilterBar() -> [AnyNode] {
        let articleState = articlesSignal.get()
        let props = CategoryFilterBar.Props(
            categoryCounts: articleState.categoryCounts,
            activeCategories: articleState.filters.categories
        )
        return CategoryFilterBar.render(props: props)
    }

    private static func renderFeedManager() -> [AnyNode] {
        let uiState = uiSignal.get()

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

    private static func renderArticleDetail() -> [AnyNode] {
        let uiState = uiSignal.get()

        guard uiState.animationPhase == .expanded,
              let articleId = uiState.expandedArticleId else {
            return []
        }

        let articles = articlesSignal.get().articles
        guard let article = articles.first(where: { $0.id == articleId }) else {
            return []
        }

        var relatedArticles: [Article] = []
        if let clusterId = article.clusterId {
            relatedArticles = articles.filter { $0.clusterId == clusterId && $0.id != article.id }
        }

        let props = ArticleDetailView.Props(article: article, relatedArticles: relatedArticles)
        return ArticleDetailView.renderGPU(props: props)
    }

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

    private static func refreshFeed(feed: Feed) async {
        do {
            let articles = try await feedService.fetchFeed(from: feed.url, feedId: feed.id)
            appStore.dispatch(ArticleAction.addArticles(articles))
            showToast("Feed refreshed: \(feed.title)")
            await processArticlesWithNLP()
            #if canImport(JavaScriptKit) && arch(wasm32)
            await extractDominantColors()
            #endif
        } catch {
            appStore.dispatch(UIAction.showError("Failed to refresh: \(error.localizedDescription)"))
        }
    }

    private static func addFeedHelper(url: String) async {
        showToast("Fetching feed...")

        do {
            let feedId = UUID().uuidString
            let articles = try await feedService.fetchFeed(from: url, feedId: feedId)

            let feed = Feed(id: feedId, title: "New Feed", description: "", url: url)
            appStore.dispatch(FeedAction.addFeed(feed))

            appStore.dispatch(ArticleAction.addArticles(articles))

            appStore.dispatch(UIAction.closeFeedManager)
            showToast("Feed added with \(articles.count) articles")

            print("✅ Feed added: \(url) with \(articles.count) articles")

            await processArticlesWithNLP()
            #if canImport(JavaScriptKit) && arch(wasm32)
            await extractDominantColors()
            #endif
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

    private static func showToast(_ message: String, duration: UInt64 = 3_000_000_000) {
        appStore.dispatch(UIAction.showToast(message))
        Task {
            try? await Task.sleep(nanoseconds: duration)
            if appStore.getState().ui.toastMessage == message {
                appStore.dispatch(UIAction.clearToast)
            }
        }
    }

    public static func setupReactiveEffects() {
        _ = Effect(execute: {
            let articles = articlesSignal.get().articles
            if !articles.isEmpty {
                Task {
                    await searchService.indexArticles(articles)
                    print("📇 Re-indexed \(articles.count) articles")
                }
            }
        })

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

        _ = Effect(execute: {
            let articleCount = articleCountSignal.get()
            let unreadCount = unreadCountSignal.get()
            print("📊 State updated: \(articleCount) articles, \(unreadCount) unread")
        })

        _ = Effect(execute: {
            let articles = articlesSignal.get().articles
            let unprocessed = articles.filter { !$0.isNLPProcessed }
            if !unprocessed.isEmpty {
                Task { await processArticlesWithNLP() }
            }
        })

        #if canImport(JavaScriptKit) && arch(wasm32)
        _ = Effect(execute: {
            let articles = articlesSignal.get().articles
            let needsColor = articles.filter { $0.dominantColor == nil && $0.enclosure?.type.hasPrefix("image/") == true }
            if !needsColor.isEmpty {
                Task { await extractDominantColors() }
            }
        })
        #endif

        print("⚡ Reactive effects initialized")
    }

    public static var services: Services {
        Services(
            feed: feedService,
            storage: storageService,
            search: searchService,
            nlp: nlpService
        )
    }

    public struct Services {
        public let feed: FeedService
        public let storage: StorageService
        public let search: SearchService
        public let nlp: NLPService
    }
}

