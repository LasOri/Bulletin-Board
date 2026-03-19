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

    public nonisolated(unsafe) static var corsProxy: String? = nil

    public init(httpClient: SecureHTTPClient? = nil) {
        self.httpClient = httpClient ?? SecureApp.createHTTPClient(
            allowedHosts: nil,
            enforceHTTPS: true
        )
    }

    public func fetchFeed(from url: String, feedId: String) async throws -> [Article] {
        guard let feedURL = URL(string: url) else {
            throw FeedError.invalidURL
        }

        let fetchURL: String
        if let proxy = FeedService.corsProxy {
            guard let encoded = feedURL.absoluteString.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ) else {
                throw FeedError.invalidURL
            }
            fetchURL = proxy + encoded
        } else {
            fetchURL = feedURL.absoluteString
        }

        do {
            let response = try await httpClient.get(fetchURL)

            guard let xmlString = response.body.stringValue else {
                throw FeedError.parseError("Expected XML string in response body")
            }

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

        let fetchURL: String
        if let proxy = FeedService.corsProxy {
            guard let encoded = websiteURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw FeedError.invalidURL
            }
            fetchURL = proxy + encoded
        } else {
            fetchURL = websiteURL
        }

        do {
            let response = try await httpClient.get(fetchURL)
            if let html = response.body.stringValue {
                let linkFeeds = parseFeedLinks(from: html, baseOrigin: origin)
                for feed in linkFeeds where !seenURLs.contains(feed.url) {
                    seenURLs.insert(feed.url)
                    discovered.append(feed)
                }
            }
        } catch {}

        let commonPaths = ["/feed", "/rss", "/atom.xml", "/feed.xml", "/rss.xml", "/index.xml", "/feeds/posts/default"]
        for path in commonPaths {
            let probeURL = origin + path
            guard !seenURLs.contains(probeURL) else { continue }

            let probeFetchURL: String
            if let proxy = FeedService.corsProxy {
                guard let encoded = probeURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { continue }
                probeFetchURL = proxy + encoded
            } else {
                probeFetchURL = probeURL
            }

            do {
                let response = try await httpClient.get(probeFetchURL)
                if let body = response.body.stringValue {
                    let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<rss") || trimmed.hasPrefix("<feed") {
                        let feedType: FeedType = trimmed.contains("<feed") ? .atom : .rss
                        seenURLs.insert(probeURL)
                        discovered.append(DiscoveredFeed(url: probeURL, title: path, type: feedType))
                    }
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

