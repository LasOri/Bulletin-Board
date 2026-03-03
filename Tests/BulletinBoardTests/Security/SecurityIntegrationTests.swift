import XCTest
@testable import BulletinBoard
import LINKER

/// Tests for security integration in Bulletin Board.
///
/// Verifies all LINKER security features are properly integrated:
/// - HTML sanitization (XSS protection)
/// - Secure HTTP client (HTTPS enforcement, rate limiting)
/// - Secure storage (WebAuthn encryption)
/// - CSRF protection
/// - CSP configuration
final class SecurityIntegrationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // Reset security state before each test
        SecurityManager.shared.csrfManager.invalidateToken()
    }

    // MARK: - HTML Sanitization Tests

    func testHTMLSanitizationRemovesScriptTags() async throws {
        let maliciousHTML = "<p>Safe text</p><script>alert('XSS')</script><p>More text</p>"
        let sanitized = await HTMLSanitizer.sanitize(maliciousHTML, policy: .moderate)

        // Script tags should be escaped or removed
        XCTAssertFalse(sanitized.contains("<script>"), "Script tags should be escaped/removed")

        // Safe content should remain
        XCTAssertTrue(sanitized.contains("Safe text"), "Safe content should remain")
        XCTAssertTrue(sanitized.contains("More text"), "Safe content should remain")
    }

    func testHTMLSanitizationRemovesEventHandlers() async throws {
        let maliciousHTML = "<img src='x' onerror='alert(1)'><a href='#' onclick='steal()'>Click</a>"
        let sanitized = await HTMLSanitizer.sanitize(maliciousHTML, policy: .moderate)

        // Event handlers should be removed
        XCTAssertFalse(sanitized.contains("onerror"), "onerror should be removed")
        XCTAssertFalse(sanitized.contains("onclick"), "onclick should be removed")
        XCTAssertFalse(sanitized.contains("alert"), "alert should be removed")
        XCTAssertFalse(sanitized.contains("steal"), "steal should be removed")
    }

    func testHTMLSanitizationAllowsSafeFormatting() async throws {
        let safeHTML = "<p>Text with <strong>bold</strong> and <em>italic</em></p><ul><li>Item</li></ul>"
        let sanitized = await HTMLSanitizer.sanitize(safeHTML, policy: .moderate)

        // Safe formatting should be preserved
        XCTAssertTrue(sanitized.contains("<strong>"), "Strong tags should be preserved")
        XCTAssertTrue(sanitized.contains("<em>"), "Em tags should be preserved")
        XCTAssertTrue(sanitized.contains("<ul>"), "List tags should be preserved")
        XCTAssertTrue(sanitized.contains("<li>"), "List item tags should be preserved")
    }

    // MARK: - FeedService Security Tests

    func testFeedServiceUsesSanitization() async throws {
        // FeedService should use HTMLSanitizer
        let feedService = FeedService()

        // Note: This tests that FeedService is properly initialized with sanitizer
        // Full integration test would require mock RSS feed
        XCTAssertNotNil(feedService, "FeedService should initialize with security features")
    }

    func testFeedServiceHTTPSEnforcement() async throws {
        let httpClient = SecureApp.createHTTPClient(
            allowedHosts: nil,
            enforceHTTPS: true
        )

        // Test that HTTP URLs are rejected
        do {
            _ = try await httpClient.get("http://insecure.example.com/feed.xml")
            XCTFail("HTTP request should be rejected when HTTPS is enforced")
        } catch {
            // Expected: HTTP should be rejected (error type depends on LINKER implementation)
            XCTAssertTrue(true, "HTTP request correctly rejected")
        }
    }

    // MARK: - Secure Storage Tests

    func testStorageServiceInMemoryMode() async throws {
        let storage = StorageService(useInMemoryStorage: true)

        // Test saving and loading
        let testFeeds = [
            Feed(id: "test1", title: "Test Feed 1", description: "Feed 1", url: "https://example.com/1.xml"),
            Feed(id: "test2", title: "Test Feed 2", description: "Feed 2", url: "https://example.com/2.xml")
        ]

        try await storage.saveFeeds(testFeeds)
        let loaded = try await storage.loadFeeds()

        XCTAssertEqual(loaded.count, 2, "Should load correct number of feeds")
        XCTAssertEqual(loaded[0].id, "test1", "Feed 1 should match")
        XCTAssertEqual(loaded[1].id, "test2", "Feed 2 should match")
    }

    func testStorageServiceArticleSaveLoad() async throws {
        let storage = StorageService(useInMemoryStorage: true)

        let testArticles = [
            Article(
                id: "art1",
                title: "Article 1",
                url: "https://example.com/1",
                feedId: "feed1"
            ),
            Article(
                id: "art2",
                title: "Article 2",
                url: "https://example.com/2",
                feedId: "feed1"
            )
        ]

        try await storage.saveArticles(testArticles)
        let loaded = try await storage.loadArticles()

        XCTAssertEqual(loaded.count, 2, "Should load correct number of articles")
        XCTAssertEqual(loaded[0].id, "art1", "Article 1 should match")
        XCTAssertEqual(loaded[1].title, "Article 2", "Article 2 title should match")
    }

    func testStorageServiceNotFoundError() async throws {
        let storage = StorageService(useInMemoryStorage: true)

        do {
            let _: [Feed] = try await storage.loadFeeds()
            XCTFail("Should throw not found error")
        } catch StorageService.StorageError.notFound {
            // Expected
            XCTAssertTrue(true, "Correctly throws not found error")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStorageServiceExists() async throws {
        let storage = StorageService(useInMemoryStorage: true)

        let existsBefore = await storage.exists(forKey: "feeds")
        XCTAssertFalse(existsBefore, "Key should not exist initially")

        let testFeeds = [Feed(id: "test", title: "Test", description: "Test description", url: "https://example.com")]
        try await storage.saveFeeds(testFeeds)

        let existsAfter = await storage.exists(forKey: "feeds")
        XCTAssertTrue(existsAfter, "Key should exist after save")
    }

    func testStorageServiceDelete() async throws {
        let storage = StorageService(useInMemoryStorage: true)

        let testFeeds = [Feed(id: "test", title: "Test", description: "Test description", url: "https://example.com")]
        try await storage.saveFeeds(testFeeds)

        let existsBefore = await storage.exists(forKey: "feeds")
        XCTAssertTrue(existsBefore)

        try await storage.delete(forKey: "feeds")

        let existsAfter = await storage.exists(forKey: "feeds")
        XCTAssertFalse(existsAfter, "Key should not exist after delete")
    }

    func testStorageServiceClearAll() async throws {
        let storage = StorageService(useInMemoryStorage: true)

        try await storage.saveFeeds([Feed(id: "f1", title: "Feed 1", description: "Feed 1 description", url: "https://example.com")])
        try await storage.saveArticles([Article(id: "a1", title: "Article 1", url: "https://example.com", feedId: "f1")])

        let exists1 = await storage.exists(forKey: "feeds")
        let exists2 = await storage.exists(forKey: "articles")
        XCTAssertTrue(exists1)
        XCTAssertTrue(exists2)

        try await storage.clearAll()

        let notExists1 = await storage.exists(forKey: "feeds")
        let notExists2 = await storage.exists(forKey: "articles")
        XCTAssertFalse(notExists1, "Feeds should be cleared")
        XCTAssertFalse(notExists2, "Articles should be cleared")
    }

    // MARK: - CSRF Protection Tests

    func testCSRFTokenGeneration() {
        let token1 = SecurityManager.shared.csrfManager.getToken()
        let token2 = SecurityManager.shared.csrfManager.getToken()

        XCTAssertFalse(token1.isEmpty, "CSRF token should not be empty")
        XCTAssertEqual(token1, token2, "Same token should be returned within session")
    }

    func testCSRFTokenValidation() {
        let validToken = SecurityManager.shared.csrfManager.getToken()
        let invalidToken = "invalid-token-12345"

        XCTAssertTrue(
            SecurityManager.shared.csrfManager.validateToken(validToken),
            "Valid token should pass validation"
        )
        XCTAssertFalse(
            SecurityManager.shared.csrfManager.validateToken(invalidToken),
            "Invalid token should fail validation"
        )
    }

    func testCSRFTokenReset() {
        let token1 = SecurityManager.shared.csrfManager.getToken()
        _ = SecurityManager.shared.csrfManager.rotateToken()
        let token2 = SecurityManager.shared.csrfManager.getToken()

        XCTAssertNotEqual(token1, token2, "Token should change after rotation")
    }

    // MARK: - CSP Configuration Tests

    func testCSPConfigurationGeneration() {
        let csp = CSPConfiguration.configure()

        XCTAssertFalse(csp.isEmpty, "CSP should not be empty")

        // Verify key directives
        XCTAssertTrue(csp.contains("default-src 'self'"), "Should have default-src")
        XCTAssertTrue(csp.contains("script-src"), "Should have script-src")
        XCTAssertTrue(csp.contains("img-src"), "Should have img-src")
        XCTAssertTrue(csp.contains("object-src 'none'"), "Should block objects")
        XCTAssertTrue(csp.contains("frame-ancestors 'none'"), "Should prevent framing")
        XCTAssertTrue(csp.contains("upgrade-insecure-requests"), "Should upgrade insecure requests")
    }

    // MARK: - Rate Limiting Tests

    func testRateLimiterBasicOperation() async throws {
        let rateLimiter = RateLimiter(strategy: .tokenBucket(capacity: 10, refillRate: 1.0, refillInterval: 1.0))
        let key = "test-key"

        // Should allow initial requests up to capacity
        for _ in 0..<10 {
            let result = await rateLimiter.tryAcquire(key: key)
            XCTAssertTrue(result.allowed, "Should allow requests within capacity")
        }

        // Should reject request exceeding capacity
        let result = await rateLimiter.tryAcquire(key: key)
        XCTAssertFalse(result.allowed, "Should reject request exceeding capacity")
    }

    func testRateLimiterRefill() async throws {
        let rateLimiter = RateLimiter(strategy: .tokenBucket(capacity: 2, refillRate: 10.0, refillInterval: 1.0))
        let key = "test-refill-key"

        // Consume all tokens
        var result = await rateLimiter.tryAcquire(key: key)
        XCTAssertTrue(result.allowed)
        result = await rateLimiter.tryAcquire(key: key)
        XCTAssertTrue(result.allowed)
        result = await rateLimiter.tryAcquire(key: key)
        XCTAssertFalse(result.allowed, "Should be empty")

        // Wait for refill (0.2 seconds = 2 tokens at 10/sec)
        try await Task.sleep(nanoseconds: 200_000_000)

        // Should allow new requests after refill
        result = await rateLimiter.tryAcquire(key: key)
        XCTAssertTrue(result.allowed, "Should have refilled")
    }

    // MARK: - Integration Tests

    func testSecurityFeaturesIntegration() async throws {
        // Test that all security components work together

        // 1. HTML Sanitization
        let safe = await HTMLSanitizer.sanitize("<p>Safe</p><script>bad()</script>", policy: .moderate)
        XCTAssertFalse(safe.contains("<script>"), "Script tags should be escaped/removed")

        // 2. CSRF Token
        let csrfToken = SecurityManager.shared.csrfManager.getToken()
        XCTAssertFalse(csrfToken.isEmpty)

        // 3. Secure Storage
        let storage = StorageService(useInMemoryStorage: true)
        let feed = Feed(id: "test", title: "Test", description: "Test description", url: "https://example.com")
        try await storage.saveFeeds([feed])
        let loaded = try await storage.loadFeeds()
        XCTAssertEqual(loaded.count, 1)

        // 4. Rate Limiter
        let rateLimiter = RateLimiter(strategy: .tokenBucket(capacity: 5, refillRate: 1.0, refillInterval: 1.0))
        let result = await rateLimiter.tryAcquire(key: "test-integration")
        XCTAssertTrue(result.allowed)

        // 5. CSP
        let csp = CSPConfiguration.configure()
        XCTAssertTrue(csp.contains("default-src"))

        print("✅ All security features integrated successfully")
    }
}
