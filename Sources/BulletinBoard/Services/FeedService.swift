import Foundation
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

    public init(httpClient: SecureHTTPClient? = nil) {
        self.httpClient = httpClient ?? SecureApp.createHTTPClient(
            allowedHosts: nil,
            enforceHTTPS: true
        )
    }

    private func buildProxiedURL(_ targetURL: String, proxy: String) -> String? {
        guard let encoded = targetURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return proxy + encoded
    }

    private func fetchViaProxies(_ targetURL: String) async throws -> String {
        guard !FeedService.corsProxies.isEmpty else {
            let response = try await httpClient.get(targetURL)
            guard let body = response.body.stringValue, !body.isEmpty else {
                throw FeedError.parseError("Expected XML string in response body")
            }
            return body
        }

        var lastError: Error = FeedError.networkError("No proxies configured")

        for proxy in FeedService.corsProxies {
            guard let fetchURL = buildProxiedURL(targetURL, proxy: proxy) else { continue }

            do {
                let response = try await httpClient.get(fetchURL)

                guard let body = response.body.stringValue, !body.isEmpty else {
                    lastError = FeedError.parseError("Proxy returned empty body")
                    continue
                }

                if body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{\"Error\"") {
                    lastError = FeedError.parseError("Proxy returned error")
                    continue
                }

                return body
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError
    }

    public func fetchFeed(from url: String, feedId: String) async throws -> [Article] {
        guard URL(string: url) != nil else {
            throw FeedError.invalidURL
        }

        do {
            let xmlString = try await fetchViaProxies(url)

            let trimmed = xmlString.trimmingCharacters(in: .whitespacesAndNewlines)
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
            let msg = error.localizedDescription
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
        guard let baseURL = URL(string: websiteURL),
              let scheme = baseURL.scheme,
              let host = baseURL.host else {
            throw FeedError.invalidURL
        }

        let origin = "\(scheme)://\(host)"
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
                let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
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

        var searchRange = html.startIndex..<html.endIndex
        while let linkStart = html.range(of: "<link ", options: .caseInsensitive, range: searchRange) {
            guard let linkEnd = html.range(of: ">", range: linkStart.upperBound..<html.endIndex) else { break }
            let linkTag = String(html[linkStart.lowerBound..<linkEnd.upperBound])
            searchRange = linkEnd.upperBound..<html.endIndex

            let isAlternate = linkTag.range(of: "rel=\"alternate\"", options: .caseInsensitive) != nil
                || linkTag.range(of: "rel='alternate'", options: .caseInsensitive) != nil
            guard isAlternate else { continue }

            let isRSS = linkTag.range(of: "application/rss+xml", options: .caseInsensitive) != nil
            let isAtom = linkTag.range(of: "application/atom+xml", options: .caseInsensitive) != nil
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
            guard let start = tag.range(of: pattern, options: .caseInsensitive) else { continue }
            let valueStart = start.upperBound
            let quote = pattern.last!
            guard let end = tag.range(of: String(quote), range: valueStart..<tag.endIndex) else { continue }
            return String(tag[valueStart..<end.lowerBound])
        }
        return nil
    }

    private func convertToArticle(_ item: RSSItem, feedId: String) async -> Article {
        let articleId = item.link
            .data(using: .utf8)
            .map { "\(feedId)-\($0.hashValue)" }
            ?? UUID().uuidString

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

