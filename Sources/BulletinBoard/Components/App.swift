import Foundation
import LINKER
#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

public enum AppLogFeature: LogFeature, CaseIterable {
    case startup
    case security
    case data
    case nlp
    case ui
    case feeds
    case storage
    case grid
    case scroll
    case gpu
    case keyboard

    public var name: String {
        switch self {
        case .startup: return "APP.STARTUP"
        case .security: return "APP.SECURITY"
        case .data: return "APP.DATA"
        case .nlp: return "APP.NLP"
        case .ui: return "APP.UI"
        case .feeds: return "APP.FEEDS"
        case .storage: return "APP.STORAGE"
        case .grid: return "APP.GRID"
        case .scroll: return "APP.SCROLL"
        case .gpu: return "APP.GPU"
        case .keyboard: return "APP.KEYBOARD"
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
        Task { await Logger.shared.info(AppLogFeature.ui, "[PERF] \(phase): \(String(format: "%.1f", elapsed))ms") }
        return now()
    }

    public static func main() async {
        let t0 = now()
        var t = t0

        await Logger.shared.configureForDevelopment()
        await Logger.shared.enable([
            AppLogFeature.startup, .data, .nlp, .ui, .feeds,
            .storage, .gpu, .security, .grid, .scroll, .keyboard
        ] as [AppLogFeature])

        let enabledNames = AppLogFeature.allCases.map { $0.name.replacingOccurrences(of: "APP.", with: "").lowercased() }
        print("[FEATURES] Enabled: \(enabledNames.joined(separator: ", "))")

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

            await Logger.shared.info(AppLogFeature.security, "All security features enabled")
        } catch {
            await Logger.shared.error(AppLogFeature.security, "Security initialization failed: \(error) — running with reduced security")
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

        #if canImport(JavaScriptKit) && arch(wasm32)
        startAutoRefresh()
        #endif
    }

    #if canImport(JavaScriptKit) && arch(wasm32)
    private static func detectGPUSupport() async {
        let supported = WebGPUBridge.isSupported()
        GPUComponentConfig.enabled = supported
        if supported {
            await GPUEffectManager.shared.ensureInitialized()
            await Logger.shared.info(AppLogFeature.gpu, "WebGPU supported — GPU effects enabled")
        } else {
            await Logger.shared.warn(AppLogFeature.gpu, "WebGPU not supported — CSS effects fallback")
        }
    }
    #elseif canImport(JavaScriptKit)
    private static func detectGPUSupport() async {
        await Logger.shared.info(AppLogFeature.gpu, "Non-WASM environment — disabling GPU effects")
        GPUComponentConfig.enabled = false
    }
    #endif

    private static func loadPersistedData() async {
        await Logger.shared.info(AppLogFeature.storage, "Loading persisted data...")

        do {
            let feeds = try await storageService.loadFeeds()
            await Logger.shared.info(AppLogFeature.storage, "Loaded \(feeds.count) feeds")

            for feed in feeds {
                appStore.dispatch(FeedAction.addFeed(feed))
            }

            let articles = try await storageService.loadArticles()
            await Logger.shared.info(AppLogFeature.storage, "Loaded \(articles.count) articles")

            appStore.dispatch(ArticleAction.addArticles(articles))

        } catch StorageService.StorageError.notFound {
            await Logger.shared.info(AppLogFeature.storage, "No persisted data found (first run)")
        } catch {
            await Logger.shared.warn(AppLogFeature.storage, "Error loading data: \(error)")
        }
    }

    private static func indexArticlesForSearch() async {
        let articles = appStore.getState().articles.articles

        if !articles.isEmpty {
            await Logger.shared.info(AppLogFeature.data, "Indexing \(articles.count) articles for search...")
            await searchService.indexArticles(articles)
            let termCount = await searchService.termCount()
            await Logger.shared.info(AppLogFeature.data, "Indexed \(termCount) unique terms")
        }
    }

    private static func processArticlesWithNLP() async {
        let articles = appStore.getState().articles.articles
        let unprocessed = articles.filter { !$0.isNLPProcessed }
        guard !unprocessed.isEmpty else { return }

        await Logger.shared.info(AppLogFeature.nlp, "Processing \(unprocessed.count) articles with NLP...")

        await nlpService.buildCorpus(from: articles)
        let results = await nlpService.processArticles(unprocessed)

        let allIds = articles.map { $0.id }
        let clusters = await nlpService.clusterArticles(allIds)
        await Logger.shared.info(AppLogFeature.nlp, "Clustering complete: \(clusters.count) articles assigned")

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

        await Logger.shared.info(AppLogFeature.nlp, "NLP processing complete for \(results.count) articles")
    }

    #if canImport(JavaScriptKit) && arch(wasm32)
    private static func extractDominantColors() async {
        let articles = appStore.getState().articles.articles
        let needsColor = articles.filter { article in
            article.dominantColor == nil &&
            article.enclosure?.type.hasPrefix("image/") == true
        }
        guard !needsColor.isEmpty else { return }

        await Logger.shared.info(AppLogFeature.gpu, "Extracting dominant colors from \(needsColor.count) images...")

        var updates: [(id: String, color: ArticleColor)] = []

        for article in needsColor {
            guard let imageURL = article.enclosure?.url else { continue }
            if let color = await ColorExtractor.extractDominantColor(from: imageURL) {
                updates.append((id: article.id, color: ArticleColor(r: color.r, g: color.g, b: color.b)))
            }
        }

        if !updates.isEmpty {
            appStore.dispatch(ArticleAction.batchUpdateDominantColors(updates))
            await Logger.shared.info(AppLogFeature.gpu, "Extracted colors for \(updates.count) articles")
        }
    }
    #endif

    #if canImport(JavaScriptKit) && arch(wasm32)
    private static func mountUI() {
        Task { await Logger.shared.info(AppLogFeature.ui, "Mounting UI...") }

        guard let document = SafeJSGlobal.global?.document.object else {
            Task { await Logger.shared.error(AppLogFeature.ui, "Failed to access document") }
            return
        }

        guard let rootElement = document.getElementById!("app").object else {
            Task { await Logger.shared.error(AppLogFeature.ui, "Root element #app not found") }
            return
        }

        let bridge = DOMBridge()
        reconciler = DOMReconciler(bridge: bridge)
        reconciler?.mount(rootElement: rootElement)

        renderToDOM()

        var renderScheduled = false
        var lastContextKey = scrollContextKey()
        _ = appStore.subscribe { _ in
            guard !renderScheduled else { return }
            renderScheduled = true
            _ = SafeJSGlobal.global?.queueMicrotask.function?(JSClosure { _ in
                renderScheduled = false
                renderToDOM()

                let newKey = scrollContextKey()
                if newKey != lastContextKey {
                    lastContextKey = newKey
                    restoreScrollPosition()
                }

                return .undefined
            })

            if let existing = saveTimerId {
                _ = SafeJSGlobal.global?.clearTimeout.function?(existing)
            }
            saveTimerId = SafeJSGlobal.global?.setTimeout.function?(JSClosure { _ in
                Task {
                    let articles = appStore.getState().articles.articles
                    let feeds = appStore.getState().feeds.feeds
                    do {
                        if !articles.isEmpty { try await storageService.saveArticles(articles) }
                        if !feeds.isEmpty { try await storageService.saveFeeds(feeds) }
                        await Logger.shared.debug(AppLogFeature.storage, "Auto-saved \(articles.count) articles, \(feeds.count) feeds")
                    } catch {
                        await Logger.shared.warn(AppLogFeature.storage, "Auto-save failed: \(error)")
                    }
                }
                return .undefined
            }, 2000)
        }

        setupEventHandlers(document: document)

        restoreScrollPosition()

        Task { await Logger.shared.info(AppLogFeature.ui, "UI mounted successfully") }
    }

    private nonisolated(unsafe) static var reconciler: DOMReconciler?
    private nonisolated(unsafe) static var saveTimerId: JSValue? = nil

    private nonisolated(unsafe) static var renderCount = 0

    private static func renderToDOM() {
        let t0 = now()
        let nodes = MainView()
        let tVdom = now()
        reconciler?.update(newTree: nodes)
        applyTheme()
        renderCount += 1
        let total = now() - t0
        let vdom = tVdom - t0
        let patch = now() - tVdom
        if renderCount <= 3 || total > 50 {
            Task { await Logger.shared.info(AppLogFeature.ui, "[PERF] renderToDOM #\(renderCount): \(String(format: "%.1f", total))ms (vdom: \(String(format: "%.1f", vdom))ms, patch: \(String(format: "%.1f", patch))ms)") }
        }
    }

    private static func applyTheme() {
        let theme = uiSignal.get().theme
        guard let body = SafeJSGlobal.global?.document.object?.body.object else { return }
        let isDark: Bool
        switch theme {
        case .dark:
            isDark = true
        case .light:
            isDark = false
        case .auto:
            let prefersDark = SafeJSGlobal.global?.matchMedia.function?("(prefers-color-scheme: dark)")
                .object?.matches
            isDark = prefersDark?.boolean ?? false
        }
        if isDark {
            _ = body.classList.object?.add!("theme-dark")
        } else {
            _ = body.classList.object?.remove!("theme-dark")
        }
    }

    private static func setupEventHandlers(document: JSObject) {
        setupClickHandler(document: document)
        setupSubmitHandler(document: document)
        setupSearchHandlers(document: document)
        setupKeyboardHandler(document: document)
        setupFileInputHandler(document: document)
        setupOnlineOfflineHandlers()
        setupScrollListener()
        CardExpansionController.shared.setupEscapeHandler(document: document)
        Task { await Logger.shared.info(AppLogFeature.ui, "Event handlers registered") }
    }

    private static func setupScrollListener() {
        #if canImport(JavaScriptKit) && arch(wasm32)
        guard let window = SafeJSGlobal.global else { return }

        if let innerH = window.innerHeight.number {
            viewportHeightSignal.set(Int(innerH))
        }

        var scrollRAFScheduled = false
        let scrollHandler = JSClosure { _ -> JSValue in
            guard !scrollRAFScheduled else { return .undefined }
            scrollRAFScheduled = true
            _ = window.requestAnimationFrame!(JSClosure { _ -> JSValue in
                scrollRAFScheduled = false
                let windowY = Int(window.scrollY.number ?? 0)
                let threshold = 170
                guard abs(windowY - lastScrollUpdateY) >= threshold else { return .undefined }
                lastScrollUpdateY = windowY

                let listOffset: Int
                if let listEl = window.document.object?.querySelector!(".article-list").object,
                   let rect = listEl.getBoundingClientRect!().object,
                   let top = rect.top.number {
                    listOffset = windowY + Int(top)
                } else {
                    listOffset = 300
                }
                let effectiveScroll = max(0, windowY - listOffset)
                scrollTopSignal.set(effectiveScroll)

                saveScrollPosition()

                _ = SafeJSGlobal.global?.queueMicrotask.function?(JSClosure { _ in
                    renderToDOM()
                    return .undefined
                })
                return .undefined
            })
            return .undefined
        }
        _ = window.addEventListener!("scroll", scrollHandler, ["passive": true])

        let resizeHandler = JSClosure { _ -> JSValue in
            if let innerH = window.innerHeight.number {
                viewportHeightSignal.set(Int(innerH))
            }
            return .undefined
        }
        _ = window.addEventListener!("resize", resizeHandler)
        #endif
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

            case "toggle-unread-filter":
                var currentFilters = appStore.getState().articles.filters
                currentFilters.showOnlyUnread.toggle()
                appStore.dispatch(ArticleAction.setFilters(currentFilters))

            case "toggle-favorites-filter":
                var currentFilters = appStore.getState().articles.filters
                currentFilters.showOnlyFavorites.toggle()
                appStore.dispatch(ArticleAction.setFilters(currentFilters))

            case "filter-date-range":
                if let rangeStr = actionEl.dataset.object?["range"].string {
                    var currentFilters = appStore.getState().articles.filters
                    switch rangeStr {
                    case "today":
                        currentFilters.dateRange = .today
                    case "week":
                        currentFilters.dateRange = .lastWeek
                    case "month":
                        currentFilters.dateRange = .lastMonth
                    default:
                        currentFilters.dateRange = nil
                    }
                    appStore.dispatch(ArticleAction.setFilters(currentFilters))
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
                    case "share-article":
                        handleShareArticle(actionEl: actionEl)
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

            case "import-opml":
                if let fileInput = SafeJSGlobal.global?.document.object?
                    .getElementById!("opml-file-input").object {
                    _ = fileInput.click!()
                }

            case "discover-feeds":
                guard let urlInput = SafeJSGlobal.global?.document.object?
                    .getElementById!("feed-url").object,
                    let url = urlInput.value.string, !url.isEmpty else {
                    break
                }
                Task {
                    isDiscovering = true
                    renderToDOM()
                    await Logger.shared.info(AppLogFeature.feeds, "Discovering feeds from \(url)")
                    do {
                        let results = try await feedService.discoverFeeds(from: url)
                        discoveredFeeds = results
                        await Logger.shared.info(AppLogFeature.feeds, "Discovered \(results.count) feeds")
                        if results.isEmpty {
                            showToast("No feeds found at \(url)")
                        }
                    } catch {
                        showToast("Discovery failed: \(error.localizedDescription)")
                        await Logger.shared.warn(AppLogFeature.feeds, "Discovery failed: \(error)")
                    }
                    isDiscovering = false
                    renderToDOM()
                }

            case "add-discovered-feed":
                if let feedURL = actionEl.dataset.object?["feedUrl"].string {
                    discoveredFeeds.removeAll { $0.url == feedURL }
                    Task {
                        await addFeedHelper(url: feedURL)
                    }
                }

            case "add-suggested-feed":
                if let feedURL = actionEl.dataset.object?["feedUrl"].string,
                   let feedName = actionEl.dataset.object?["feedName"].string {
                    showToast("Adding \(feedName)...")
                    Task {
                        await addFeedHelper(url: feedURL)
                    }
                }

            case "dismiss-discovered":
                discoveredFeeds.removeAll()
                renderToDOM()

            case "export-opml":
                let feeds = appStore.getState().feeds.feeds
                let opmlXML = OPMLService.generateOPML(feeds: feeds)
                exportOPMLFile(opmlXML)

            case "mark-all-read":
                appStore.dispatch(ArticleAction.markAllAsRead)
                showToast("All articles marked as read")

            case "set-sort-order":
                if let sortStr = actionEl.dataset.object?["sort"].string {
                    let order: ArticleSortOrder
                    switch sortStr {
                    case "newest": order = .newest
                    case "oldest": order = .oldest
                    case "title": order = .title
                    case "feed": order = .feed
                    case "category": order = .category
                    default: return JSValue.undefined
                    }
                    appStore.dispatch(ArticleAction.setSortOrder(order))
                }

            case "toggle-view-mode":
                viewMode = viewMode == .list ? .grid : .list
                Task { await Logger.shared.info(AppLogFeature.grid, "View mode: \(viewMode.rawValue)") }
                renderToDOM()

            case "toggle-archived-filter":
                var currentFilters = appStore.getState().articles.filters
                currentFilters.showArchived.toggle()
                appStore.dispatch(ArticleAction.setFilters(currentFilters))

            case "archive-article":
                if let articleEl = target.closest!("[data-article-id]").object,
                   let articleId = articleEl.dataset.object?["articleId"].string {
                    appStore.dispatch(ArticleAction.archiveArticle(id: articleId))
                    showToast("Article archived")
                }

            case "unarchive-article":
                if let articleEl = target.closest!("[data-article-id]").object,
                   let articleId = articleEl.dataset.object?["articleId"].string {
                    appStore.dispatch(ArticleAction.unarchiveArticle(id: articleId))
                    showToast("Article restored")
                }

            case "bulk-archive-read":
                let readIds = appStore.getState().articles.articles
                    .filter { $0.isRead && !$0.isArchived }
                    .map { $0.id }
                if !readIds.isEmpty {
                    appStore.dispatch(ArticleAction.archiveMultiple(readIds))
                    showToast("Archived \(readIds.count) read articles")
                }

            case "delete-older":
                if let daysStr = actionEl.dataset.object?["days"].string,
                   let days = Int(daysStr) {
                    let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
                    appStore.dispatch(ArticleAction.deleteOlderThan(cutoff))
                    showToast("Deleted articles older than \(days) days")
                }

            case "open-settings":
                appStore.dispatch(UIAction.toggleSettings)

            case "close-settings", "close-settings-overlay":
                appStore.dispatch(UIAction.toggleSettings)

            case "set-theme":
                if let themeStr = actionEl.dataset.object?["theme"].string {
                    let theme: Theme
                    switch themeStr {
                    case "light": theme = .light
                    case "dark": theme = .dark
                    default: theme = .auto
                    }
                    appStore.dispatch(UIAction.setTheme(theme))
                }

            case "save-feed-edit":
                if let feedId = actionEl.dataset.object?["feedId"].string,
                   let titleInput = SafeJSGlobal.global?.document.object?
                    .getElementById!("edit-feed-title-\(feedId)").object,
                   let newTitle = titleInput.value.string {
                    if let feed = appStore.getState().feeds.feeds.first(where: { $0.id == feedId }) {
                        let updated = Feed(
                            id: feed.id, title: newTitle, description: feed.description,
                            url: feed.url, siteUrl: feed.siteUrl, language: feed.language,
                            iconUrl: feed.iconUrl, userCategory: feed.userCategory,
                            updateFrequency: feed.updateFrequency, lastFetched: feed.lastFetched,
                            lastSuccessfulFetch: feed.lastSuccessfulFetch, lastError: feed.lastError,
                            articleCount: feed.articleCount, unreadCount: feed.unreadCount,
                            subscribedAt: feed.subscribedAt, updatedAt: Date(),
                            isEnabled: feed.isEnabled, isFetching: feed.isFetching
                        )
                        appStore.dispatch(FeedAction.updateFeed(id: feedId, updated))
                        showToast("Feed updated")
                    }
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
                Task { await Logger.shared.warn(AppLogFeature.feeds, "Feed URL input not found or empty") }
                return JSValue.undefined
            }

            let feedURL: String
            if let preview = feedPreview,
               case .success(let feeds, _) = preview.state,
               let firstFeed = feeds.first {
                feedURL = firstFeed.url
            } else {
                feedURL = url
            }

            urlInput.value = .string("")
            feedPreview = nil

            Task {
                await addFeedHelper(url: feedURL)
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
            Task { await Logger.shared.debug(AppLogFeature.feeds, "Edit feed: \(feedId)") }

        case "delete":
            appStore.dispatch(FeedAction.removeFeed(id: feedId))
            showToast("Feed removed")

        default:
            break
        }
    }

    #if canImport(JavaScriptKit) && arch(wasm32)
    private static func handleShareArticle(actionEl: JSObject) {
        guard let url = actionEl.dataset.object?["articleUrl"].string,
              let title = actionEl.dataset.object?["articleTitle"].string else {
            return
        }

        if let navigator = SafeJSGlobal.global?.navigator.object,
           let share = navigator.share.function {
            let shareData = JSObject.global.Object.function!.new()
            shareData.title = .string(title)
            shareData.url = .string(url)

            _ = share(shareData)

            Task { await Logger.shared.info(AppLogFeature.ui, "Shared article via Web Share API: \(title)") }
        } else {
            if let navigator = SafeJSGlobal.global?.navigator.object,
               let clipboard = navigator.clipboard.object {
                _ = clipboard.writeText!(url)
                showToast("Link copied to clipboard!")
                Task { await Logger.shared.info(AppLogFeature.ui, "Copied article URL to clipboard: \(url)") }
            } else {
                showToast("Share not supported")
            }
        }
    }
    #else
    private static func handleShareArticle(actionEl: JSObject) {}
    #endif

    #if canImport(JavaScriptKit) && arch(wasm32)
    private static func setupOnlineOfflineHandlers() {
        guard let window = SafeJSGlobal.global else { return }

        isOffline = !(window.navigator.object?.onLine.boolean ?? true)

        let onlineHandler = JSClosure { _ -> JSValue in
            isOffline = false
            renderToDOM()
            showToast("Back online")
            Task { await Logger.shared.info(AppLogFeature.ui, "Network: online") }
            return .undefined
        }

        let offlineHandler = JSClosure { _ -> JSValue in
            isOffline = true
            renderToDOM()
            showToast("You're offline - using cached data")
            Task { await Logger.shared.warn(AppLogFeature.ui, "Network: offline") }
            return .undefined
        }

        _ = window.addEventListener!("online", onlineHandler)
        _ = window.addEventListener!("offline", offlineHandler)
    }
    #else
    private static func setupOnlineOfflineHandlers() {}
    #endif

    private static func startAutoRefresh() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)

                let uiState = appStore.getState().ui
                if uiState.animationPhase == .expanded { continue }

                let feeds = appStore.getState().feeds.feeds
                var totalNew = 0
                var refreshedFeedTitle = ""

                for feed in feeds where feed.needsUpdate() {
                    do {
                        let existingCount = appStore.getState().articles.articles
                            .filter { $0.feedId == feed.id }.count
                        let articles = try await feedService.fetchFeed(from: feed.url, feedId: feed.id)
                        appStore.dispatch(ArticleAction.addArticles(articles))
                        let newCount = appStore.getState().articles.articles
                            .filter { $0.feedId == feed.id }.count - existingCount
                        if newCount > 0 {
                            totalNew += newCount
                            refreshedFeedTitle = feed.title
                        }
                    } catch {
                        Task { await Logger.shared.warn(AppLogFeature.feeds, "Auto-refresh failed for \(feed.title): \(error)") }
                    }
                }

                if totalNew > 0 {
                    let message = totalNew == 1
                        ? "1 new article from \(refreshedFeedTitle)"
                        : "\(totalNew) new articles"
                    showToast(message)
                    await processArticlesWithNLP()
                    #if canImport(JavaScriptKit) && arch(wasm32)
                    await extractDominantColors()
                    #endif
                }
            }
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
                Task { await Logger.shared.error(AppLogFeature.feeds, "Failed to refresh \(feed.title): \(error)") }
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

            if targetId == "search-input" {
                let query = target.value.string ?? ""
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if !Task.isCancelled {
                        appStore.dispatch(ArticleAction.setSearchQuery(query))

                        if !query.isEmpty {
                            let results = await searchService.search(query: query)
                            let searchResults = results.map { result in
                                SearchResult(
                                    articleId: result.articleId,
                                    score: result.score,
                                    matchedFields: result.matchedFields
                                )
                            }
                            appStore.dispatch(ArticleAction.setSearchResults(searchResults))
                        } else {
                            appStore.dispatch(ArticleAction.setSearchResults(nil))
                        }
                    }
                }
            } else if targetId == "feed-url" {
                let url = target.value.string ?? ""
                feedDiscoveryTask?.cancel()

                if url.isEmpty {
                    feedPreview = nil
                    renderToDOM()
                } else if url.hasPrefix("http://") || url.hasPrefix("https://") {
                    feedPreview = FeedPreview(inputURL: url, state: .discovering)
                    renderToDOM()

                    feedDiscoveryTask = Task {
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        if Task.isCancelled { return }

                        do {
                            let discovered = try await feedService.discoverFeeds(from: url)
                            if Task.isCancelled { return }

                            if discovered.isEmpty {
                                let articles = try await feedService.fetchFeed(from: url, feedId: "preview")
                                let samples = articles.prefix(3).map {
                                    FeedPreview.PreviewArticle(title: $0.title, publishedAt: $0.publishedAt)
                                }
                                let directFeed = DiscoveredFeed(url: url, title: "Direct Feed", type: .unknown)
                                feedPreview = FeedPreview(inputURL: url, state: .success([directFeed], sampleArticles: samples))
                            } else {
                                let firstFeed = discovered.first?.url ?? url
                                let articles = try await feedService.fetchFeed(from: firstFeed, feedId: "preview")
                                let samples = articles.prefix(3).map {
                                    FeedPreview.PreviewArticle(title: $0.title, publishedAt: $0.publishedAt)
                                }
                                feedPreview = FeedPreview(inputURL: url, state: .success(discovered, sampleArticles: samples))
                            }
                            renderToDOM()
                        } catch {
                            if Task.isCancelled { return }
                            feedPreview = FeedPreview(inputURL: url, state: .error(error.localizedDescription))
                            renderToDOM()
                        }
                    }
                }
            }

            return JSValue.undefined
        }

        document.addEventListener!("input", inputHandler)
    }

    private static func setupKeyboardHandler(document: JSObject) {
        let handler = JSClosure { args -> JSValue in
            guard args.count > 0,
                  let event = args[0].object,
                  let key = event.key.string else {
                return .undefined
            }

            if let activeTag = SafeJSGlobal.global?.document.object?
                .activeElement.object?.tagName.string?.lowercased(),
               activeTag == "input" || activeTag == "textarea" {
                return .undefined
            }

            let uiState = appStore.getState().ui

            switch key {
            case "j", "k":
                let articles = filteredArticlesSignal.get()
                guard !articles.isEmpty else { return .undefined }

                let currentId = appStore.getState().articles.selectedId
                let currentIndex = articles.firstIndex(where: { $0.id == currentId })

                let newIndex: Int
                if key == "j" {
                    newIndex = min((currentIndex ?? -1) + 1, articles.count - 1)
                } else {
                    newIndex = max((currentIndex ?? 1) - 1, 0)
                }

                let targetId = articles[newIndex].id
                appStore.dispatch(ArticleAction.selectArticle(id: targetId))

                let estimatedY = newIndex * 340
                scrollTopSignal.set(max(0, estimatedY - viewportHeightSignal.get() / 2))
                lastScrollUpdateY = Int(SafeJSGlobal.global?.scrollY.number ?? 0)
                renderToDOM()

                if let el = SafeJSGlobal.global?.document.object?
                    .querySelector!("[data-article-id=\"\(targetId)\"]").object {
                    _ = el.scrollIntoView!(["behavior": "smooth", "block": "nearest"])
                }

            case "o", "Enter":
                if uiState.animationPhase != .expanded,
                   let selectedId = appStore.getState().articles.selectedId {
                    CardExpansionController.shared.beginExpand(articleId: selectedId)
                }

            case "f":
                if let selectedId = appStore.getState().articles.selectedId {
                    appStore.dispatch(ArticleAction.toggleFavorite(id: selectedId))
                }

            case "m":
                if let selectedId = appStore.getState().articles.selectedId {
                    appStore.dispatch(ArticleAction.markAsRead(id: selectedId))
                }

            case "r":
                Task { await refreshAllFeeds() }

            case "/":
                _ = event.preventDefault!()
                if let searchInput = SafeJSGlobal.global?.document.object?
                    .getElementById!("search-input").object {
                    _ = searchInput.focus!()
                }

            default:
                break
            }

            return .undefined
        }

        document.addEventListener!("keydown", handler)
    }

    private static func setupFileInputHandler(document: JSObject) {
        let changeHandler = JSClosure { args -> JSValue in
            guard args.count > 0,
                  let event = args[0].object,
                  let target = event.target.object else {
                return .undefined
            }

            let targetId = target.id.string ?? ""
            guard targetId == "opml-file-input" else { return .undefined }

            guard let files = target.files.object,
                  let file = files.item!(0).object else {
                return .undefined
            }

            guard let fileReaderConstructor = SafeJSGlobal.global?.FileReader.function else {
                return .undefined
            }

            let reader = fileReaderConstructor.new()

            let onLoad = JSClosure { args -> JSValue in
                guard args.count > 0,
                      let event = args[0].object,
                      let result = event.target.object?.result.string else {
                    return .undefined
                }

                let feeds = OPMLService.parseOPML(xml: result)
                guard !feeds.isEmpty else {
                    showToast("No feeds found in OPML file")
                    return .undefined
                }

                Task {
                    var addedCount = 0
                    for feedEntry in feeds {
                        await addFeedHelper(url: feedEntry.url)
                        addedCount += 1
                    }
                    showToast("Imported \(addedCount) feeds from OPML")
                }

                return .undefined
            }

            reader.onload = .object(onLoad)
            _ = reader.readAsText!(file)

            target.value = .string("")

            return .undefined
        }

        document.addEventListener!("change", changeHandler)
    }

    private static func exportOPMLFile(_ xml: String) {
        guard let blobConstructor = SafeJSGlobal.global?.Blob.function,
              let urlObj = SafeJSGlobal.global?.URL.object else {
            return
        }

        let array = SafeJSGlobal.global?.Array.function?.new()
        _ = array?.push!(xml)
        let options = SafeJSGlobal.global?.Object.function?.new()
        options?.type = .string("application/xml")
        let blob = blobConstructor.new(array!, options!)

        guard let downloadURL = urlObj.createObjectURL!(blob).string else {
            return
        }

        guard let document = SafeJSGlobal.global?.document.object else { return }

        let a = document.createElement!("a")
        guard let link = a.object else { return }
        link.href = .string(downloadURL)
        link.download = .string("bulletin-board-feeds.opml")
        link.style.object?.display = .string("none")
        _ = document.body.object?.appendChild!(link)
        _ = link.click!()
        _ = document.body.object?.removeChild!(link)
        _ = urlObj.revokeObjectURL!(downloadURL)
    }

    #elseif canImport(JavaScriptKit)
    private static func mountUI() {
        Task { await Logger.shared.info(AppLogFeature.ui, "DOM mounting only available in WASM environment") }
    }
    #endif

    private nonisolated(unsafe) static var scrollTopSignal = MutableSignal<Int>(0)
    private nonisolated(unsafe) static var viewportHeightSignal = MutableSignal<Int>(800)
    private nonisolated(unsafe) static var lastScrollUpdateY: Int = -1000
    private nonisolated(unsafe) static var discoveredFeeds: [DiscoveredFeed] = []
    private nonisolated(unsafe) static var isDiscovering: Bool = false
    private nonisolated(unsafe) static var feedPreview: FeedPreview? = nil
    private nonisolated(unsafe) static var feedDiscoveryTask: Task<Void, Never>? = nil
    private nonisolated(unsafe) static var scrollSaveTimerId: JSValue? = nil
    private nonisolated(unsafe) static var viewMode: ViewMode = .list
    private nonisolated(unsafe) static var isOffline: Bool = false

    private static func scrollContextKey() -> String {
        let state = appStore.getState().articles
        let sort = state.sortBy.rawValue
        let cats = state.filters.categories.map { $0.rawValue }.sorted().joined(separator: ",")
        let search = state.searchQuery
        let unread = state.filters.showOnlyUnread ? "u" : ""
        let favs = state.filters.showOnlyFavorites ? "f" : ""
        return "\(sort)-\(cats)-\(search)-\(unread)\(favs)"
    }

    #if canImport(JavaScriptKit) && arch(wasm32)
    private static func saveScrollPosition() {
        if let existing = scrollSaveTimerId {
            _ = SafeJSGlobal.global?.clearTimeout.function?(existing)
        }
        let windowY = Int(SafeJSGlobal.global?.scrollY.number ?? 0)
        let key = scrollContextKey()
        scrollSaveTimerId = SafeJSGlobal.global?.setTimeout.function?(JSClosure { _ -> JSValue in
            Task {
                try? await storageService.save(windowY, forKey: "scroll_\(key)")
                await Logger.shared.debug(AppLogFeature.scroll, "Saved scroll position \(windowY) for context \(key)")
            }
            return .undefined
        }, 2000)
    }

    private static func restoreScrollPosition() {
        let key = scrollContextKey()
        Task {
            do {
                let saved: Int = try await storageService.load(forKey: "scroll_\(key)")
                if saved > 0 {
                    _ = SafeJSGlobal.global?.scrollTo!(0, saved)
                    lastScrollUpdateY = saved
                    await Logger.shared.debug(AppLogFeature.scroll, "Restored scroll position \(saved) for context \(key)")
                }
            } catch {}
        }
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
        children.append(contentsOf: renderSettings())
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
        var children: [AnyNode] = [
            AnyNode(Element<AnyHTMLContext>(
                tag: "h1",
                attributes: [Attribute(name: "class", value: "app-header__title")],
                children: [
                    AnyNode(Element<AnyHTMLContext>(
                        tag: "img",
                        attributes: [
                            Attribute(name: "src", value: "logo.svg"),
                            Attribute(name: "alt", value: "Bulletin Board"),
                            Attribute(name: "class", value: "app-header__logo"),
                            Attribute(name: "width", value: "32"),
                            Attribute(name: "height", value: "32")
                        ],
                        children: []
                    )),
                    AnyNode(Text("Bulletin Board"))
                ]
            )),
            AnyNode(Element<AnyHTMLContext>(
                tag: "p",
                children: [AnyNode(Text("Your Personal News Feed Reader"))]
            )),
            AnyNode(renderStats())
        ]

        if isOffline {
            children.append(AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "offline-indicator")],
                children: [AnyNode(Icons.wrap(Icons.wifiOff())), AnyNode(Text(" Offline Mode"))]
            )))
        }

        return Element<AnyHTMLContext>(
            tag: "header",
            attributes: [Attribute(name: "class", value: "app-header")],
            children: children
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
            children.append(contentsOf: renderEmptyState())
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
            let scrollTop = scrollTopSignal.get()
            let config = ArticleList.VirtualScrollConfig(
                itemHeight: 340,
                bufferSize: 5,
                containerHeight: viewportHeightSignal.get()
            )

            switch viewMode {
            case .grid:
                children.append(contentsOf: CategoryGrid.render(
                    props: listProps,
                    scrollTop: scrollTop,
                    config: config
                ))
            case .list:
                children.append(contentsOf: ArticleList.renderVirtualGPU(
                    props: listProps,
                    scrollTop: scrollTop,
                    config: config
                ))
            }
        }

        return Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "app-content")],
            children: children
        )
    }

    private static func renderEmptyState() -> [AnyNode] {
        struct SuggestedFeed {
            let name: String
            let url: String
            let description: String
            let category: String
        }

        let suggestions = [
            SuggestedFeed(
                name: "Hacker News",
                url: "https://hnrss.org/frontpage",
                description: "Tech news and discussion",
                category: "Tech"
            ),
            SuggestedFeed(
                name: "TechCrunch",
                url: "https://techcrunch.com/feed/",
                description: "Startup and technology news",
                category: "Tech"
            ),
            SuggestedFeed(
                name: "Ars Technica",
                url: "https://feeds.arstechnica.com/arstechnica/index",
                description: "Technology news and analysis",
                category: "Tech"
            ),
            SuggestedFeed(
                name: "The Verge",
                url: "https://www.theverge.com/rss/index.xml",
                description: "Technology, science, art, and culture",
                category: "Tech"
            ),
            SuggestedFeed(
                name: "MIT Technology Review",
                url: "https://www.technologyreview.com/feed/",
                description: "Emerging technology and innovation",
                category: "Science"
            ),
            SuggestedFeed(
                name: "Wired",
                url: "https://www.wired.com/feed/rss",
                description: "Technology, business, and culture",
                category: "Tech"
            )
        ]

        var children: [AnyNode] = []

        children.append(AnyNode(Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "empty-state__header")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "h2",
                    children: [AnyNode(Text("Welcome to Bulletin Board!"))]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "p",
                    children: [AnyNode(Text("Get started by adding your first RSS feed"))]
                ))
            ]
        )))

        children.append(AnyNode(Element<AnyHTMLContext>(
            tag: "button",
            attributes: [
                Attribute(name: "type", value: "button"),
                Attribute(name: "class", value: "empty-state__cta"),
                Attribute(name: "data-action", value: "open-feed-manager")
            ],
            children: [AnyNode(Icons.wrap(Icons.plus())), AnyNode(Text(" Add Your First Feed"))]
        )))

        children.append(AnyNode(Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "empty-state__divider")],
            children: [AnyNode(Text("or try one of these popular feeds"))]
        )))

        var suggestionCards: [AnyNode] = []
        for feed in suggestions {
            let card = Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "suggested-feed-card")],
                children: [
                    AnyNode(Element<AnyHTMLContext>(
                        tag: "div",
                        attributes: [Attribute(name: "class", value: "suggested-feed-card__header")],
                        children: [
                            AnyNode(Element<AnyHTMLContext>(
                                tag: "span",
                                attributes: [Attribute(name: "class", value: "suggested-feed-card__name")],
                                children: [AnyNode(Text(feed.name))]
                            )),
                            AnyNode(Element<AnyHTMLContext>(
                                tag: "span",
                                attributes: [Attribute(name: "class", value: "suggested-feed-card__category")],
                                children: [AnyNode(Text(feed.category))]
                            ))
                        ]
                    )),
                    AnyNode(Element<AnyHTMLContext>(
                        tag: "p",
                        attributes: [Attribute(name: "class", value: "suggested-feed-card__description")],
                        children: [AnyNode(Text(feed.description))]
                    )),
                    AnyNode(Element<AnyHTMLContext>(
                        tag: "button",
                        attributes: [
                            Attribute(name: "type", value: "button"),
                            Attribute(name: "class", value: "suggested-feed-card__button"),
                            Attribute(name: "data-action", value: "add-suggested-feed"),
                            Attribute(name: "data-feed-url", value: feed.url),
                            Attribute(name: "data-feed-name", value: feed.name)
                        ],
                        children: [AnyNode(Text("Add Feed"))]
                    ))
                ]
            )

            #if canImport(JavaScriptKit) && arch(wasm32)
            if GPUComponentConfig.isEnabled(for: "SuggestedFeedCard") {
                let blurredCard = ShadowView(
                    id: "suggestion-shadow-\(feed.url.hashValue)",
                    style: .elevation2,
                    mouseReactive: true
                ) {
                    return BlurView(
                        id: "suggestion-blur-\(feed.url.hashValue)",
                        style: .tinted(r: 0.3, g: 0.3, b: 0.3, a: 0.4, radius: 6, saturation: 1.2),
                        intensity: 0.8
                    ) {
                        return [AnyNode(card)]
                    }
                }
                suggestionCards.append(contentsOf: blurredCard)
            } else {
                suggestionCards.append(AnyNode(card))
            }
            #else
            suggestionCards.append(AnyNode(card))
            #endif
        }

        children.append(AnyNode(Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "suggested-feeds-grid")],
            children: suggestionCards
        )))

        let emptyContainer = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "app-empty")],
            children: children
        )

        return [AnyNode(emptyContainer)]
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
        let articlesState = articlesSignal.get()
        let filters = articlesState.filters
        let currentSort = articlesState.sortBy

        let currentRange: String = {
            guard let dr = filters.dateRange else { return "all" }
            switch dr {
            case .today: return "today"
            case .lastWeek: return "week"
            case .lastMonth: return "month"
            case .custom: return "all"
            }
        }()

        func dateRangePill(_ label: String, _ range: String) -> AnyNode {
            let pillClass = "date-filter-pill" + (currentRange == range ? " date-filter-pill--active" : "")
            return AnyNode(Element<AnyHTMLContext>(
                tag: "button",
                attributes: [
                    Attribute(name: "type", value: "button"),
                    Attribute(name: "class", value: pillClass),
                    Attribute(name: "data-action", value: "filter-date-range"),
                    Attribute(name: "data-range", value: range)
                ],
                children: [AnyNode(Text(label))]
            ))
        }

        func sortPill(_ label: String, _ order: String) -> AnyNode {
            let pillClass = "date-filter-pill" + (currentSort.rawValue == label ? " date-filter-pill--active" : "")
            return AnyNode(Element<AnyHTMLContext>(
                tag: "button",
                attributes: [
                    Attribute(name: "type", value: "button"),
                    Attribute(name: "class", value: pillClass),
                    Attribute(name: "data-action", value: "set-sort-order"),
                    Attribute(name: "data-sort", value: order)
                ],
                children: [AnyNode(Text(label))]
            ))
        }

        let toolbar = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "app-toolbar")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "toolbar-group")],
                    children: [
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "button",
                            attributes: [
                                Attribute(name: "type", value: "button"),
                                Attribute(name: "class", value: "toolbar-button toolbar-button--primary"),
                                Attribute(name: "data-action", value: "open-feed-manager"),
                                Attribute(name: "aria-label", value: "Add new feed")
                            ],
                            children: [AnyNode(Icons.wrap(Icons.plus())), AnyNode(Text("Add Feed"))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "button",
                            attributes: [
                                Attribute(name: "type", value: "button"),
                                Attribute(name: "class", value: "toolbar-button toolbar-button--secondary"),
                                Attribute(name: "data-action", value: "refresh-all"),
                                Attribute(name: "aria-label", value: "Refresh all feeds")
                            ],
                            children: [AnyNode(Icons.wrap(Icons.refresh())), AnyNode(Text("Refresh"))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "button",
                            attributes: [
                                Attribute(name: "type", value: "button"),
                                Attribute(name: "class", value: "toolbar-button toolbar-button--secondary"),
                                Attribute(name: "data-action", value: "mark-all-read"),
                                Attribute(name: "aria-label", value: "Mark all as read")
                            ],
                            children: [AnyNode(Icons.wrap(Icons.checkAll())), AnyNode(Text("Mark All Read"))]
                        ))
                    ]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "toolbar-separator")],
                    children: []
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "toolbar-group")],
                    children: [
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "button",
                            attributes: [
                                Attribute(name: "type", value: "button"),
                                Attribute(name: "class", value: "toolbar-button toolbar-button--toggle" + (filters.showOnlyUnread ? " toolbar-button--active" : "")),
                                Attribute(name: "data-action", value: "toggle-unread-filter"),
                                Attribute(name: "aria-label", value: "Show unread only")
                            ],
                            children: [AnyNode(Icons.wrap(Icons.mail())), AnyNode(Text("Unread"))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "button",
                            attributes: [
                                Attribute(name: "type", value: "button"),
                                Attribute(name: "class", value: "toolbar-button toolbar-button--toggle" + (filters.showOnlyFavorites ? " toolbar-button--active" : "")),
                                Attribute(name: "data-action", value: "toggle-favorites-filter"),
                                Attribute(name: "aria-label", value: "Show favorites only")
                            ],
                            children: [AnyNode(Icons.wrap(Icons.favorites())), AnyNode(Text("Favorites"))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "button",
                            attributes: [
                                Attribute(name: "type", value: "button"),
                                Attribute(name: "class", value: "toolbar-button toolbar-button--toggle" + (filters.showArchived ? " toolbar-button--active" : "")),
                                Attribute(name: "data-action", value: "toggle-archived-filter"),
                                Attribute(name: "aria-label", value: "Show archived articles")
                            ],
                            children: [AnyNode(Icons.wrap(Icons.archive())), AnyNode(Text("Archived"))]
                        ))
                    ]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "toolbar-separator")],
                    children: []
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "toolbar-group")],
                    children: [
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "button",
                            attributes: [
                                Attribute(name: "type", value: "button"),
                                Attribute(name: "class", value: "toolbar-button toolbar-button--icon-only" + (viewMode == .grid ? " toolbar-button--active" : "")),
                                Attribute(name: "data-action", value: "toggle-view-mode"),
                                Attribute(name: "aria-label", value: viewMode == .grid ? "Switch to list view" : "Switch to grid view")
                            ],
                            children: [AnyNode(viewMode == .grid ? Icons.list() : Icons.grid())]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "button",
                            attributes: [
                                Attribute(name: "type", value: "button"),
                                Attribute(name: "class", value: "toolbar-button toolbar-button--icon-only"),
                                Attribute(name: "data-action", value: "open-settings"),
                                Attribute(name: "aria-label", value: "Settings")
                            ],
                            children: [AnyNode(Icons.settings())]
                        ))
                    ]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "date-filter-group")],
                    children: [
                        dateRangePill("All Time", "all"),
                        dateRangePill("Today", "today"),
                        dateRangePill("This Week", "week"),
                        dateRangePill("This Month", "month")
                    ]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "sort-group")],
                    children: [
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "span",
                            attributes: [Attribute(name: "class", value: "sort-group__label")],
                            children: [AnyNode(Text("Sort:"))]
                        )),
                        sortPill("Newest First", "newest"),
                        sortPill("Oldest First", "oldest"),
                        sortPill("Title (A-Z)", "title"),
                        sortPill("By Feed", "feed"),
                        sortPill("By Category", "category")
                    ]
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

        var modalChildren = FeedManager.renderGPU(props: props)

        if let preview = feedPreview {
            modalChildren.append(contentsOf: renderFeedPreview(preview: preview))
        }

        var discoverSection: [AnyNode] = []

        discoverSection.append(AnyNode(Element<AnyHTMLContext>(
            tag: "button",
            attributes: [
                Attribute(name: "type", value: "button"),
                Attribute(name: "class", value: "toolbar-button"),
                Attribute(name: "data-action", value: "discover-feeds"),
                Attribute(name: "style", value: "margin: 8px 16px")
            ],
            children: [AnyNode(Text(isDiscovering ? "Discovering..." : "Discover Feeds"))]
        )))

        if !discoveredFeeds.isEmpty {
            var feedItems: [AnyNode] = []
            feedItems.append(AnyNode(Element<AnyHTMLContext>(
                tag: "h4",
                attributes: [Attribute(name: "style", value: "margin: 0 0 8px 0")],
                children: [AnyNode(Text("Discovered Feeds (\(discoveredFeeds.count))"))]
            )))

            for feed in discoveredFeeds {
                let typeLabel = feed.type == .atom ? "Atom" : (feed.type == .rss ? "RSS" : "Feed")
                let title = feed.title ?? feed.url
                feedItems.append(AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "discovered-feed-item")],
                    children: [
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "span",
                            attributes: [Attribute(name: "class", value: "discovered-feed-item__title")],
                            children: [AnyNode(Text("[\(typeLabel)] \(title)"))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "button",
                            attributes: [
                                Attribute(name: "type", value: "button"),
                                Attribute(name: "class", value: "toolbar-button toolbar-button--primary"),
                                Attribute(name: "data-action", value: "add-discovered-feed"),
                                Attribute(name: "data-feed-url", value: feed.url)
                            ],
                            children: [AnyNode(Text("+ Add"))]
                        ))
                    ]
                )))
            }

            feedItems.append(AnyNode(Element<AnyHTMLContext>(
                tag: "button",
                attributes: [
                    Attribute(name: "type", value: "button"),
                    Attribute(name: "class", value: "toolbar-button"),
                    Attribute(name: "data-action", value: "dismiss-discovered"),
                    Attribute(name: "style", value: "margin-top: 8px")
                ],
                children: [AnyNode(Text("Dismiss"))]
            )))

            discoverSection.append(AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "discovered-feeds-list")],
                children: feedItems
            )))
        }

        if !discoverSection.isEmpty {
            modalChildren.append(AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "discover-section")],
                children: discoverSection
            )))
        }

        let modal = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "modal-overlay"),
                Attribute(name: "role", value: "dialog"),
                Attribute(name: "aria-modal", value: "true"),
                Attribute(name: "aria-label", value: "Feed Manager"),
                Attribute(name: "data-action", value: "close-feed-manager-overlay")
            ],
            children: modalChildren
        )

        return [AnyNode(modal)]
    }

    private static func renderFeedPreview(preview: FeedPreview) -> [AnyNode] {
        var children: [AnyNode] = []

        switch preview.state {
        case .idle:
            break

        case .discovering:
            children.append(AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "feed-preview feed-preview--loading")],
                children: [AnyNode(Text("Discovering feeds..."))]
            )))

        case .success(let feeds, let samples):
            var previewChildren: [AnyNode] = []

            if feeds.count == 1 {
                previewChildren.append(AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "feed-preview__title")],
                    children: [AnyNode(Icons.check(size: 14)), AnyNode(Text(" Feed found: \(feeds[0].title ?? "Untitled")"))]
                )))
            } else {
                previewChildren.append(AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "feed-preview__title")],
                    children: [AnyNode(Icons.check(size: 14)), AnyNode(Text(" Found \(feeds.count) feeds"))]
                )))
            }

            if !samples.isEmpty {
                previewChildren.append(AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "feed-preview__subtitle")],
                    children: [AnyNode(Text("Sample articles:"))]
                )))

                for sample in samples {
                    previewChildren.append(AnyNode(Element<AnyHTMLContext>(
                        tag: "div",
                        attributes: [Attribute(name: "class", value: "feed-preview__article")],
                        children: [AnyNode(Text(sample.title))]
                    )))
                }
            }

            children.append(AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "feed-preview feed-preview--success")],
                children: previewChildren
            )))

        case .error(let message):
            children.append(AnyNode(Element<AnyHTMLContext>(
                tag: "div",
                attributes: [Attribute(name: "class", value: "feed-preview feed-preview--error")],
                children: [AnyNode(Text("\(message)"))]
            )))
        }

        return children
    }

    private static func renderSettings() -> [AnyNode] {
        let uiState = uiSignal.get()
        guard uiState.isSettingsOpen else { return [] }

        let currentTheme = uiState.theme

        func themePill(_ label: String, _ value: String) -> AnyNode {
            let isActive = currentTheme.rawValue == label
            let pillClass = "date-filter-pill" + (isActive ? " date-filter-pill--active" : "")
            return AnyNode(Element<AnyHTMLContext>(
                tag: "button",
                attributes: [
                    Attribute(name: "type", value: "button"),
                    Attribute(name: "class", value: pillClass),
                    Attribute(name: "data-action", value: "set-theme"),
                    Attribute(name: "data-theme", value: value)
                ],
                children: [AnyNode(Text(label))]
            ))
        }

        let unreadCount = unreadCountSignal.get()
        let readCount = articlesSignal.get().articles.filter { $0.isRead && !$0.isArchived }.count
        let archivedCount = articlesSignal.get().articles.filter { $0.isArchived }.count

        let content = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [Attribute(name: "class", value: "settings-panel")],
            children: [
                AnyNode(Element<AnyHTMLContext>(
                    tag: "header",
                    attributes: [Attribute(name: "class", value: "settings-panel__header")],
                    children: [
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "h2",
                            attributes: [Attribute(name: "class", value: "settings-panel__title")],
                            children: [AnyNode(Text("Settings"))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "button",
                            attributes: [
                                Attribute(name: "type", value: "button"),
                                Attribute(name: "class", value: "feed-manager__close"),
                                Attribute(name: "data-action", value: "close-settings"),
                                Attribute(name: "aria-label", value: "Close")
                            ],
                            children: [AnyNode(Icons.close(size: 16))]
                        ))
                    ]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "settings-panel__section")],
                    children: [
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "h3",
                            attributes: [Attribute(name: "class", value: "settings-panel__section-title")],
                            children: [AnyNode(Text("Theme"))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "div",
                            attributes: [Attribute(name: "class", value: "settings-panel__pills")],
                            children: [
                                themePill("Light", "light"),
                                themePill("Dark", "dark"),
                                themePill("Auto", "auto")
                            ]
                        ))
                    ]
                )),
                AnyNode(Element<AnyHTMLContext>(
                    tag: "div",
                    attributes: [Attribute(name: "class", value: "settings-panel__section")],
                    children: [
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "h3",
                            attributes: [Attribute(name: "class", value: "settings-panel__section-title")],
                            children: [AnyNode(Text("Bulk Actions"))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "p",
                            attributes: [Attribute(name: "class", value: "settings-panel__info")],
                            children: [AnyNode(Text("\(unreadCount) unread, \(readCount) read, \(archivedCount) archived"))]
                        )),
                        AnyNode(Element<AnyHTMLContext>(
                            tag: "div",
                            attributes: [Attribute(name: "class", value: "settings-panel__actions")],
                            children: [
                                AnyNode(Element<AnyHTMLContext>(
                                    tag: "button",
                                    attributes: [
                                        Attribute(name: "type", value: "button"),
                                        Attribute(name: "class", value: "toolbar-button"),
                                        Attribute(name: "data-action", value: "mark-all-read")
                                    ],
                                    children: [AnyNode(Icons.wrap(Icons.check())), AnyNode(Text(" Mark All Read"))]
                                )),
                                AnyNode(Element<AnyHTMLContext>(
                                    tag: "button",
                                    attributes: [
                                        Attribute(name: "type", value: "button"),
                                        Attribute(name: "class", value: "toolbar-button"),
                                        Attribute(name: "data-action", value: "bulk-archive-read")
                                    ],
                                    children: [AnyNode(Icons.wrap(Icons.archive())), AnyNode(Text(" Archive All Read"))]
                                )),
                                AnyNode(Element<AnyHTMLContext>(
                                    tag: "button",
                                    attributes: [
                                        Attribute(name: "type", value: "button"),
                                        Attribute(name: "class", value: "toolbar-button"),
                                        Attribute(name: "data-action", value: "delete-older"),
                                        Attribute(name: "data-days", value: "30")
                                    ],
                                    children: [AnyNode(Icons.wrap(Icons.trash())), AnyNode(Text(" Delete Older Than 30 Days"))]
                                )),
                                AnyNode(Element<AnyHTMLContext>(
                                    tag: "button",
                                    attributes: [
                                        Attribute(name: "type", value: "button"),
                                        Attribute(name: "class", value: "toolbar-button"),
                                        Attribute(name: "data-action", value: "delete-older"),
                                        Attribute(name: "data-days", value: "7")
                                    ],
                                    children: [AnyNode(Icons.wrap(Icons.trash())), AnyNode(Text(" Delete Older Than 7 Days"))]
                                ))
                            ]
                        ))
                    ]
                ))
            ]
        )

        #if canImport(JavaScriptKit) && arch(wasm32)
        if GPUComponentConfig.isEnabled(for: "SettingsPanel") {
            let blurredContent = BlurView(
                id: "settings-blur",
                style: .tinted(r: 0.2, g: 0.2, b: 0.2, a: 0.45, radius: 8, saturation: 1.0),
                intensity: 1.0
            ) {
                return [AnyNode(content)]
            }
            let modal = Element<AnyHTMLContext>(
                tag: "div",
                attributes: [
                    Attribute(name: "class", value: "modal-overlay"),
                    Attribute(name: "role", value: "dialog"),
                    Attribute(name: "aria-modal", value: "true"),
                    Attribute(name: "aria-label", value: "Settings"),
                    Attribute(name: "data-action", value: "close-settings-overlay")
                ],
                children: blurredContent
            )
            return [AnyNode(modal)]
        }
        #endif

        let modal = Element<AnyHTMLContext>(
            tag: "div",
            attributes: [
                Attribute(name: "class", value: "modal-overlay"),
                Attribute(name: "role", value: "dialog"),
                Attribute(name: "aria-modal", value: "true"),
                Attribute(name: "aria-label", value: "Settings"),
                Attribute(name: "data-action", value: "close-settings-overlay")
            ],
            children: [AnyNode(content)]
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
                    children: [AnyNode(Icons.close(size: 14))]
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

            Task { await Logger.shared.info(AppLogFeature.feeds, "Feed added: \(url) with \(articles.count) articles") }

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
            Task { await Logger.shared.error(AppLogFeature.feeds, "Failed to add feed: \(error)") }
        } catch {
            appStore.dispatch(UIAction.showError("Failed to add feed: \(error.localizedDescription)"))
            Task { await Logger.shared.error(AppLogFeature.feeds, "Failed to add feed: \(error)") }
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
                    await Logger.shared.debug(AppLogFeature.data, "Re-indexed \(articles.count) articles")
                }
            }
        })

        _ = Effect(execute: {
            let articleCount = articleCountSignal.get()
            let unreadCount = unreadCountSignal.get()
            Task { await Logger.shared.debug(AppLogFeature.data, "State updated: \(articleCount) articles, \(unreadCount) unread") }
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

        Task { await Logger.shared.info(AppLogFeature.ui, "Reactive effects initialized") }
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

