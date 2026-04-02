import LINKER

public actor FeedService {

    public enum FeedError: Error, Equatable {
        case invalidURL
        case networkError(String)
        case corsBlocked(String)
        case parseError(String)
        case noItems
        case rateLimitExceeded
    }

    private let httpClient: SecureHTTPClient

    public nonisolated(unsafe) static var corsProxies: [String] = []

    private nonisolated(unsafe) static var proxyLastFailed: [String: Double] = [:]
    private static let proxyCooldownSeconds: Double = 60

    public init(httpClient: SecureHTTPClient? = nil) {
        self.httpClient = httpClient ?? SecureApp.createHTTPClient(
            allowedHosts: nil,
            enforceHTTPS: true
        )
    }

    private func buildProxiedURL(_ targetURL: String, proxy: String) -> String? {
        let encoded = targetURL.percentEncodeForURL()
        return proxy + encoded
    }

    private static let maxRetriesPerProxy = 2
    private static let baseRetryDelayMs: UInt64 = 800_000_000

    private func isProxyHealthy(_ proxy: String) -> Bool {
        guard let lastFailed = FeedService.proxyLastFailed[proxy] else {
            return true
        }
        return currentTimestamp() - lastFailed >= FeedService.proxyCooldownSeconds
    }

    private func markProxyFailed(_ proxy: String) {
        FeedService.proxyLastFailed[proxy] = currentTimestamp()
    }

    private func markProxySuccess(_ proxy: String) {
        FeedService.proxyLastFailed.removeValue(forKey: proxy)
    }

    private func fetchViaProxies(_ targetURL: String) async throws -> String {
        guard !FeedService.corsProxies.isEmpty else {
            let response = try await httpClient.get(targetURL)
            guard let body = response.body.stringValue, !body.isEmpty else {
                throw FeedError.parseError("Expected XML string in response body")
            }
            return body
        }

        let healthyProxies = FeedService.corsProxies.filter { isProxyHealthy($0) }
        let proxiesToTry = healthyProxies.isEmpty ? FeedService.corsProxies : healthyProxies

        var lastError: Error = FeedError.networkError("No proxies configured")

        for proxy in proxiesToTry {
            guard let fetchURL = buildProxiedURL(targetURL, proxy: proxy) else { continue }

            for attempt in 0..<FeedService.maxRetriesPerProxy {
                if attempt > 0 {
                    try await Task.sleep(nanoseconds: FeedService.baseRetryDelayMs * UInt64(attempt))
                }

                do {
                    let response = try await httpClient.get(fetchURL)

                    if response.statusCode >= 500 {
                        lastError = FeedError.networkError("Proxy returned HTTP \(response.statusCode)")
                        continue
                    }

                    if response.statusCode == 429 {
                        lastError = FeedError.rateLimitExceeded
                        markProxyFailed(proxy)
                        break
                    }

                    guard let body = response.body.stringValue, !body.isEmpty else {
                        lastError = FeedError.parseError("Proxy returned empty body")
                        continue
                    }

                    let trimmedBody = body.trimmingWhitespace()

                    if trimmedBody.hasPrefix("{\"Error\"") {
                        lastError = FeedError.parseError("Proxy returned error JSON")
                        continue
                    }

                    if trimmedBody.hasPrefix("error code:") {
                        lastError = FeedError.networkError("Proxy upstream error: \(trimmedBody)")
                        continue
                    }

                    if body.count < 50 && !trimmedBody.hasPrefix("<?xml") && !trimmedBody.hasPrefix("<rss") && !trimmedBody.hasPrefix("<feed") && !trimmedBody.hasPrefix("<") {
                        lastError = FeedError.parseError("Proxy returned non-XML short response")
                        continue
                    }

                    markProxySuccess(proxy)
                    return body
                } catch {
                    lastError = error
                    continue
                }
            }

            markProxyFailed(proxy)
        }

        throw lastError
    }

    public struct FetchResult: Sendable {
        public let feed: Feed
        public let articles: [Article]
    }

    public func fetchFeedWithMetadata(from url: String, feedId: String) async throws -> FetchResult {
        guard url.isValidURL() else {
            throw FeedError.invalidURL
        }

        do {
            let xmlString = try await fetchViaProxies(url)

            let trimmed = xmlString.trimmingWhitespace()
            if trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<html") {
                throw FeedError.parseError("URL returned an HTML page, not an RSS/Atom feed")
            }

            let rssFeed = try RSSParser.parse(xmlString)

            guard !rssFeed.items.isEmpty else {
                throw FeedError.noItems
            }

            var feed = Feed.from(rssFeed: rssFeed, url: url)
            feed = Feed(
                id: feedId, title: feed.title, description: feed.description,
                url: feed.url, siteUrl: feed.siteUrl, language: feed.language
            )

            let articles = await withTaskGroup(of: Article.self) { [self] group in
                for item in rssFeed.items {
                    group.addTask {
                        await self.convertToArticle(item, feedId: feedId)
                    }
                }

                var result: [Article] = []
                for await article in group {
                    result.append(article)
                }
                return result
            }

            return FetchResult(feed: feed, articles: articles)
        } catch let error as FeedError {
            throw error
        } catch {
            let msg = "\(error)"
            if msg.contains("TypeError") || msg.contains("Failed to fetch") || msg.contains("NetworkError") {
                throw FeedError.corsBlocked(
                    "Cannot fetch this feed due to cross-origin restrictions. " +
                    "The feed server doesn't allow browser requests."
                )
            }
            throw FeedError.networkError(msg)
        }
    }

    public func fetchFeed(from url: String, feedId: String) async throws -> [Article] {
        guard url.isValidURL() else {
            throw FeedError.invalidURL
        }

        do {
            let xmlString = try await fetchViaProxies(url)

            let trimmed = xmlString.trimmingWhitespace()
            if trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<html") {
                throw FeedError.parseError("URL returned an HTML page, not an RSS/Atom feed")
            }

            let rssFeed = try RSSParser.parse(xmlString)

            guard !rssFeed.items.isEmpty else {
                throw FeedError.noItems
            }

            return await withTaskGroup(of: Article.self) { [self] group in
                for item in rssFeed.items {
                    group.addTask {
                        await self.convertToArticle(item, feedId: feedId)
                    }
                }

                var articles: [Article] = []
                for await article in group {
                    articles.append(article)
                }
                return articles
            }
        } catch let error as FeedError {
            throw error
        } catch {
            let msg = "\(error)"
            if msg.contains("TypeError") || msg.contains("Failed to fetch") || msg.contains("NetworkError") {
                throw FeedError.corsBlocked(
                    "Cannot fetch this feed due to cross-origin restrictions. " +
                    "The feed server doesn't allow browser requests."
                )
            }
            throw FeedError.networkError(msg)
        }
    }

    public func discoverFeeds(from websiteURL: String) async throws -> [DiscoveredFeed] {
        guard let parts = websiteURL.urlSchemeAndHost() else {
            throw FeedError.invalidURL
        }

        let origin = "\(parts.scheme)://\(parts.host)"
        var discovered: [DiscoveredFeed] = []
        var seenURLs: Set<String> = []

        do {
            let html = try await fetchViaProxies(websiteURL)
            let linkFeeds = parseFeedLinks(from: html, baseOrigin: origin)
            for feed in linkFeeds where !seenURLs.contains(feed.url) {
                seenURLs.insert(feed.url)
                discovered.append(feed)
            }
        } catch {}

        let commonPaths = ["/feed", "/rss", "/atom.xml", "/feed.xml", "/rss.xml", "/index.xml", "/feeds/posts/default"]
        for path in commonPaths {
            let probeURL = origin + path
            guard !seenURLs.contains(probeURL) else { continue }

            do {
                let body = try await fetchViaProxies(probeURL)
                let trimmed = body.trimmingWhitespace()
                if trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<rss") || trimmed.hasPrefix("<feed") {
                    let feedType: FeedType = trimmed.contains("<feed") ? .atom : .rss
                    seenURLs.insert(probeURL)
                    discovered.append(DiscoveredFeed(url: probeURL, title: path, type: feedType))
                }
            } catch {}
        }

        return discovered
    }

    private func parseFeedLinks(from html: String, baseOrigin: String) -> [DiscoveredFeed] {
        var feeds: [DiscoveredFeed] = []

        var searchStart = html.startIndex
        while let linkStart = html.findRangeIgnoringCase(of: "<link ", from: searchStart) {
            guard let linkEnd = html.findRange(of: ">", from: linkStart.upperBound) else { break }
            let linkTag = String(html[linkStart.lowerBound..<linkEnd.upperBound])
            searchStart = linkEnd.upperBound

            let isAlternate = linkTag.findRangeIgnoringCase(of: "rel=\"alternate\"") != nil
                || linkTag.findRangeIgnoringCase(of: "rel='alternate'") != nil
            guard isAlternate else { continue }

            let isRSS = linkTag.findRangeIgnoringCase(of: "application/rss+xml") != nil
            let isAtom = linkTag.findRangeIgnoringCase(of: "application/atom+xml") != nil
            guard isRSS || isAtom else { continue }

            guard let href = extractAttribute("href", from: linkTag) else { continue }
            let title = extractAttribute("title", from: linkTag)

            let resolvedURL: String
            if href.hasPrefix("http://") || href.hasPrefix("https://") {
                resolvedURL = href
            } else if href.hasPrefix("/") {
                resolvedURL = baseOrigin + href
            } else {
                resolvedURL = baseOrigin + "/" + href
            }

            feeds.append(DiscoveredFeed(
                url: resolvedURL,
                title: title,
                type: isAtom ? .atom : .rss
            ))
        }

        return feeds
    }

    private func extractAttribute(_ name: String, from tag: String) -> String? {
        let patterns = ["\(name)=\"", "\(name)='"]
        for pattern in patterns {
            guard let start = tag.findRangeIgnoringCase(of: pattern) else { continue }
            let valueStart = start.upperBound
            let quote = String(pattern.last!)
            guard let end = tag.findRange(of: quote, from: valueStart) else { continue }
            return String(tag[valueStart..<end.lowerBound])
        }
        return nil
    }

    private func convertToArticle(_ item: RSSItem, feedId: String) async -> Article {
        let articleId = "\(feedId)-\(item.link.hashValue)"

        let sanitizedDescription = await item.description.asyncMap { rawHTML in
            await HTMLSanitizer.sanitize(rawHTML, policy: .moderate)
        }

        let sanitizedContent = await item.content.asyncMap { rawHTML in
            await HTMLSanitizer.sanitize(rawHTML, policy: .moderate)
        }

        let enclosure = item.enclosure.map { rssEnc in
            ArticleEnclosure(
                url: rssEnc.url,
                type: rssEnc.type,
                length: rssEnc.length
            )
        }

        return Article(
            id: articleId,
            title: item.title,
            description: sanitizedDescription,
            content: sanitizedContent,
            url: item.link,
            publishedAt: item.pubDate,
            author: item.author,
            feedId: feedId,
            categories: item.categories,
            enclosure: enclosure
        )
    }
}

extension Optional {
    fileprivate func asyncMap<U>(_ transform: (Wrapped) async throws -> U) async rethrows -> U? {
        if let value = self {
            return try await transform(value)
        }
        return nil
    }
}
