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

