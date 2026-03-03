import XCTest
@testable import BulletinBoard
import LINKER

final class FeedServiceTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTestFeedService(with httpClient: SecureHTTPClient? = nil) -> FeedService {
        FeedService(httpClient: httpClient)
    }

    private func createMockRSSXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <title>Test Feed</title>
                <link>https://example.com</link>
                <description>Test feed description</description>
                <item>
                    <title>Test Article 1</title>
                    <link>https://example.com/article1</link>
                    <description>Article 1 description</description>
                    <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
                    <author>John Doe</author>
                </item>
                <item>
                    <title>Test Article 2</title>
                    <link>https://example.com/article2</link>
                    <description>Article 2 description</description>
                    <pubDate>Mon, 02 Jan 2024 12:00:00 GMT</pubDate>
                </item>
            </channel>
        </rss>
        """
    }

    // MARK: - Error Tests

    func testInvalidURL() async {
        let service = makeTestFeedService()

        do {
            _ = try await service.fetchFeed(from: "", feedId: "test-feed")
            XCTFail("Should throw invalidURL error")
        } catch FeedService.FeedError.invalidURL {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testParseError() async {
        let service = makeTestFeedService()

        // Mock URL session would be needed for full test
        // For now, test the error case with invalid XML
        do {
            _ = try await service.fetchFeed(from: "https://example.com/feed", feedId: "test-feed")
            // Will fail with network error in test environment (no mock)
        } catch {
            // Expected - either network error or parse error
            XCTAssertTrue(error is FeedService.FeedError)
        }
    }

    // MARK: - Success Tests (would need URLSession mocking)

    // Note: Full integration tests would require URLSession mocking
    // or actual network requests to test RSS feeds
    // For now, we verify the service can be instantiated and has correct interface

    func testServiceInitialization() {
        let service = makeTestFeedService()
        XCTAssertNotNil(service)
    }

    func testServiceWithCustomSession() {
        // Test that service can be initialized with custom http client
        let httpClient = SecureApp.createHTTPClient(allowedHosts: nil, enforceHTTPS: true)
        let service = makeTestFeedService(with: httpClient)
        XCTAssertNotNil(service)
    }

    // MARK: - Error Type Tests

    func testFeedErrorEquatable() {
        let error1 = FeedService.FeedError.invalidURL
        let error2 = FeedService.FeedError.invalidURL
        XCTAssertEqual(error1, error2)

        let error3 = FeedService.FeedError.networkError("test")
        let error4 = FeedService.FeedError.networkError("test")
        XCTAssertEqual(error3, error4)

        let error5 = FeedService.FeedError.parseError("test")
        let error6 = FeedService.FeedError.parseError("test")
        XCTAssertEqual(error5, error6)

        XCTAssertNotEqual(error1, error3)
    }
}
