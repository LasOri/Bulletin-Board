import Foundation
import LINKER

/// Service for fetching and parsing RSS/Atom feeds.
///
/// Uses LINKER's SecureHTTPClient for secure network requests with:
/// - HTTPS enforcement
/// - Rate limiting (100 burst, 10/sec sustained)
/// - CSRF protection
/// - Host validation
///
/// Uses LINKER's HTMLSanitizer for XSS protection on feed content.
/// Uses LINKER's RSSParser for feed parsing and converts to Article models.
public actor FeedService {

    // MARK: - Error Types

    public enum FeedError: Error, Equatable {
        case invalidURL
        case networkError(String)
        case parseError(String)
        case noItems
        case rateLimitExceeded
    }

    // MARK: - Properties

    private let httpClient: SecureHTTPClient

    // MARK: - Initialization

    public init(httpClient: SecureHTTPClient? = nil) {
        // Use provided or create secure defaults
        self.httpClient = httpClient ?? SecureApp.createHTTPClient(
            allowedHosts: nil,      // Allow all hosts (RSS feeds are external)
            enforceHTTPS: true      // Enforce HTTPS for security
        )
    }

    // MARK: - Public Methods

    /// Fetches and parses a feed from the given URL.
    /// - Parameters:
    ///   - url: The feed URL to fetch
    ///   - feedId: The feed ID to associate with parsed articles
    /// - Returns: Array of parsed articles with sanitized content
    /// - Throws: FeedError if fetching or parsing fails
    public func fetchFeed(from url: String, feedId: String) async throws -> [Article] {
        guard let feedURL = URL(string: url) else {
            throw FeedError.invalidURL
        }

        // Fetch feed data with SecureHTTPClient
        // Automatically applies:
        // - HTTPS enforcement
        // - Rate limiting
        // - CSRF tokens
        // - Host validation
        do {
            let response = try await httpClient.get(feedURL.absoluteString)

            // Convert Json body to string for XML parsing
            guard let xmlString = response.body.stringValue else {
                throw FeedError.parseError("Expected XML string in response body")
            }

            let rssFeed = try RSSParser.parse(xmlString)

            guard !rssFeed.items.isEmpty else {
                throw FeedError.noItems
            }

            // Convert RSS items to Articles with sanitized content
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
        } catch {
            // Map SecureHTTPClient errors to FeedError
            throw FeedError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    /// Converts an RSS item to an Article model with sanitized HTML content.
    /// Applies XSS protection by sanitizing all HTML in descriptions and content.
    private func convertToArticle(_ item: RSSItem, feedId: String) async -> Article {
        // Generate unique ID from link or use UUID
        let articleId = item.link
            .data(using: .utf8)
            .map { "\(feedId)-\($0.hashValue)" }
            ?? UUID().uuidString

        // Sanitize HTML content to prevent XSS attacks
        // HTMLSanitizer removes dangerous tags/attributes while preserving safe formatting
        let sanitizedDescription = await item.description.asyncMap { rawHTML in
            await HTMLSanitizer.sanitize(rawHTML, policy: .moderate)
        }

        let sanitizedContent = await item.content.asyncMap { rawHTML in
            await HTMLSanitizer.sanitize(rawHTML, policy: .moderate)
        }

        // Convert RSSEnclosure to ArticleEnclosure if present
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
            description: sanitizedDescription,  // ✅ XSS protected
            content: sanitizedContent,          // ✅ XSS protected
            url: item.link,
            publishedAt: item.pubDate,
            author: item.author,
            feedId: feedId,
            categories: item.categories,
            enclosure: enclosure
        )
    }
}

// Helper extension for async map
extension Optional {
    fileprivate func asyncMap<U>(_ transform: (Wrapped) async throws -> U) async rethrows -> U? {
        if let value = self {
            return try await transform(value)
        }
        return nil
    }
}
