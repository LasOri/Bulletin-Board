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
        case corsBlocked(String)
        case parseError(String)
        case noItems
        case rateLimitExceeded
    }

    // MARK: - Properties

    private let httpClient: SecureHTTPClient

    /// CORS proxy URL prefix. Set to nil to disable.
    /// Example: "https://api.allorigins.win/raw?url="
    public nonisolated(unsafe) static var corsProxy: String? = nil

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

        // Try direct fetch first, fall back to CORS proxy if available
        let fetchURL: String
        if let proxy = FeedService.corsProxy {
            // Use CORS proxy to avoid cross-origin restrictions
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

            // Check if we got an HTML error page instead of XML
            let trimmed = xmlString.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<html") {
                throw FeedError.parseError("URL returned an HTML page, not an RSS/Atom feed")
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
        } catch let error as FeedError {
            throw error
        } catch {
            let msg = error.localizedDescription
            // Detect CORS-like failures
            if msg.contains("TypeError") || msg.contains("Failed to fetch") || msg.contains("NetworkError") {
                throw FeedError.corsBlocked(
                    "Cannot fetch this feed due to cross-origin restrictions. " +
                    "The feed server doesn't allow browser requests."
                )
            }
            throw FeedError.networkError(msg)
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
