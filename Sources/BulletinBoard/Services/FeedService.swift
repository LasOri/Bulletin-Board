import Foundation
import LINKER

/// Service for fetching and parsing RSS/Atom feeds.
///
/// Uses LINKER's RSSParser for feed parsing and converts to Article models.
/// Handles network requests, parsing, and error cases.
public actor FeedService {

    // MARK: - Error Types

    public enum FeedError: Error, Equatable {
        case invalidURL
        case networkError(String)
        case parseError(String)
        case noItems
    }

    // MARK: - Properties

    private let urlSession: URLSession

    // MARK: - Initialization

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - Public Methods

    /// Fetches and parses a feed from the given URL.
    /// - Parameters:
    ///   - url: The feed URL to fetch
    ///   - feedId: The feed ID to associate with parsed articles
    /// - Returns: Array of parsed articles
    /// - Throws: FeedError if fetching or parsing fails
    public func fetchFeed(from url: String, feedId: String) async throws -> [Article] {
        guard let feedURL = URL(string: url) else {
            throw FeedError.invalidURL
        }

        // Fetch feed data
        let (data, response) = try await urlSession.data(from: feedURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FeedError.networkError("Invalid response")
        }

        // Parse XML
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw FeedError.parseError("Unable to decode XML")
        }

        do {
            let rssFeed = try RSSParser.parse(xmlString)

            guard !rssFeed.items.isEmpty else {
                throw FeedError.noItems
            }

            // Convert RSS items to Articles
            return rssFeed.items.map { item in
                convertToArticle(item, feedId: feedId)
            }
        } catch {
            throw FeedError.parseError(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    /// Converts an RSS item to an Article model.
    private func convertToArticle(_ item: RSSItem, feedId: String) -> Article {
        // Generate unique ID from link or use UUID
        let articleId = item.link
            .data(using: .utf8)
            .map { "\(feedId)-\($0.hashValue)" }
            ?? UUID().uuidString

        // Convert RSSEnclosure to ArticleEnclosure if present
        let enclosure = item.enclosure.map { rssEnc in
            ArticleEnclosure(
                url: rssEnc.url,
                type: rssEnc.type ?? "unknown",
                length: rssEnc.length
            )
        }

        return Article(
            id: articleId,
            title: item.title,
            description: item.description,
            content: item.content,
            url: item.link,
            publishedAt: item.pubDate,
            author: item.author,
            feedId: feedId,
            categories: item.categories,
            enclosure: enclosure
        )
    }
}
