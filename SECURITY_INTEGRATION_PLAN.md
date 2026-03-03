# Security Integration Plan for Bulletin Board

## Current Status: ⚠️ NO SECURITY FEATURES ENABLED

Bulletin Board currently has **ZERO** security measures implemented despite LINKER providing comprehensive security features.

## Security Risks

### 1. **XSS Vulnerabilities** (HIGH RISK)
- **Issue**: Article content/descriptions from RSS feeds are not sanitized
- **Attack**: Malicious RSS feeds could inject JavaScript
- **Impact**: Session hijacking, data theft, malware injection
- **Current Code**: Using `Text()` which is safe, but `content` field could contain HTML

### 2. **No Rate Limiting** (MEDIUM RISK)
- **Issue**: No protection against feed fetch abuse
- **Attack**: Excessive requests to external RSS feeds
- **Impact**: DDoS external servers, resource exhaustion

### 3. **No CSRF Protection** (MEDIUM RISK)
- **Issue**: Feed management actions (add/delete) not protected
- **Attack**: Cross-site request forgery to modify user's feeds
- **Impact**: Unauthorized feed modifications

### 4. **Insecure Storage** (HIGH RISK)
- **Issue**: Feed list, articles, user preferences stored without encryption
- **Attack**: Browser extension malware, physical access
- **Impact**: Privacy breach, feed manipulation

### 5. **No HTTPS Enforcement** (MEDIUM RISK)
- **Issue**: External RSS feeds could be fetched over HTTP
- **Attack**: Man-in-the-middle attacks
- **Impact**: Content tampering, credential theft

### 6. **No Content Security Policy** (LOW RISK)
- **Issue**: No CSP headers configured
- **Attack**: XSS via injected content
- **Impact**: Reduced defense-in-depth

## LINKER Security Features Available

### ✅ Built-in Security Components

1. **HTMLSanitizer** - XSS protection for user-generated/feed content
2. **CSRFProtection** - CSRF tokens for state-modifying actions
3. **RateLimiter** - Token bucket algorithm for API rate limiting
4. **SecureHTTPClient** - HTTPS enforcement, host validation, automatic CSRF tokens
5. **SecureStorage** - AES-256-GCM encrypted IndexedDB with passphrase
6. **TransparentSecureStorage** - WebAuthn hardware-backed encryption
7. **SecureWebSocket** - HMAC authentication for WebSockets
8. **WebAuthnKeyManager** - Hardware security keys (YubiKey, TouchID, Windows Hello)
9. **CSPBuilder** - Content Security Policy header generation
10. **SecurityManager** - Centralized security configuration

### 🚀 One-Line Activation

```swift
try await LINKERSecurity.enableAllSecurity(
    htmlPolicy: .strict,
    csrfTokenLifetime: 3600,
    rateLimitCapacity: 100,
    rateLimitRefillRate: 10,
    enforceHTTPS: true,
    allowedHosts: nil,
    enableWebAuthn: true,
    webAuthnRpId: "bulletin-board.app"
)
```

## Implementation Plan

### Phase 1: Critical Security (Immediate)

#### 1.1 HTML Sanitization
**File**: `Sources/BulletinBoard/Services/FeedService.swift`

```swift
import LINKER

public actor FeedService {
    private let httpClient: SecureHTTPClient
    private let sanitizer: HTMLSanitizer

    public init() {
        self.httpClient = SecureApp.createHTTPClient(
            allowedHosts: nil,
            enforceHTTPS: true
        )
        self.sanitizer = HTMLSanitizer(policy: .moderate)
    }

    private func convertToArticle(_ item: RSSItem, feedId: String) -> Article {
        // Sanitize HTML content
        let sanitizedDescription = item.description.map {
            sanitizer.sanitize($0)
        }
        let sanitizedContent = item.content.map {
            sanitizer.sanitize($0)
        }

        return Article(
            // ...
            description: sanitizedDescription,
            content: sanitizedContent,
            // ...
        )
    }
}
```

#### 1.2 Secure HTTP Client
**File**: `Sources/BulletinBoard/Services/FeedService.swift`

Replace `URLSession` with `SecureHTTPClient`:

```swift
public func fetchFeed(from url: String, feedId: String) async throws -> [Article] {
    // SecureHTTPClient automatically:
    // - Enforces HTTPS
    // - Validates hosts
    // - Applies rate limiting
    // - Adds CSRF tokens
    let data = try await httpClient.get(url: url)

    guard let xmlString = String(data: data, encoding: .utf8) else {
        throw FeedError.parseError("Unable to decode XML")
    }

    // ... rest of parsing
}
```

#### 1.3 Secure Storage
**File**: `Sources/BulletinBoard/Services/StorageService.swift`

Replace `IndexedDB` with `TransparentSecureStorage`:

```swift
import LINKER

public actor StorageService {
    private var secureStorage: TransparentSecureStorage?

    public init() {}

    private func getStorage() async throws -> TransparentSecureStorage {
        if let storage = secureStorage {
            return storage
        }

        // WebAuthn hardware-backed encryption (YubiKey, TouchID, etc.)
        let storage = try await SecureApp.createSecureStorageWithWebAuthn(
            name: "bulletin_board"
        )
        self.secureStorage = storage
        return storage
    }

    public func saveFeeds(_ feeds: [Feed]) async throws {
        let storage = try await getStorage()
        let encoder = JSONEncoder()
        let data = try encoder.encode(feeds)
        try await storage.set(key: "feeds", value: data)
    }

    public func loadFeeds() async throws -> [Feed] {
        let storage = try await getStorage()
        guard let data = try await storage.get(key: "feeds") else {
            throw StorageError.notFound
        }
        let decoder = JSONDecoder()
        return try decoder.decode([Feed].self, from: data)
    }
}
```

### Phase 2: Application Security

#### 2.1 Initialize Security in App
**File**: `Sources/BulletinBoard/Components/App.swift`

```swift
public static func main() async {
    print("🗞️ Bulletin Board - Starting...")

    // Initialize security FIRST
    do {
        try await LINKERSecurity.enableAllSecurity(
            htmlPolicy: .moderate,          // Allow some HTML formatting
            csrfTokenLifetime: 3600,        // 1 hour CSRF token lifetime
            rateLimitCapacity: 100,         // 100 requests burst
            rateLimitRefillRate: 10,        // 10 requests/second sustained
            enforceHTTPS: true,             // Only HTTPS for external feeds
            allowedHosts: nil,              // Allow all hosts (RSS feeds)
            enableWebAuthn: true,           // Hardware-backed encryption
            webAuthnRpId: "bulletin-board.app"
        )

        let status = LINKERSecurity.getSecurityStatus()
        status.printStatus()
    } catch {
        print("⚠️ Security initialization failed: \(error)")
        print("⚠️ Running with REDUCED security")
    }

    // Detect GPU support
    #if canImport(JavaScriptKit) && arch(wasm32)
    detectGPUSupport()
    #endif

    // ... rest of initialization
}
```

#### 2.2 CSP Headers Configuration
**File**: `Sources/BulletinBoard/Security/CSPConfiguration.swift` (NEW)

```swift
import LINKER

public struct CSPConfiguration {
    public static func configure() -> String {
        let csp = CSPBuilder()
            .defaultSrc([.`self`])
            .scriptSrc([.`self`, .unsafeInline])  // For WASM
            .styleSrc([.`self`, .unsafeInline])
            .imgSrc([.`self`, .data, .https])     // Allow external images
            .connectSrc([.`self`, .https])        // Allow RSS feeds
            .fontSrc([.`self`, .data])
            .objectSrc([.none])
            .baseUri([.`self`])
            .formAction([.`self`])
            .frameAncestors([.none])
            .upgradeInsecureRequests()

        return csp.build()
    }
}
```

### Phase 3: Feed Management Security

#### 3.1 CSRF-Protected Feed Actions
**File**: `Sources/BulletinBoard/Components/FeedManager.swift`

Add CSRF tokens to forms:

```swift
private static func renderAddFeedForm() -> Element<AnyHTMLContext> {
    let csrfToken = SecurityManager.shared.csrfManager.getToken()

    return Element<AnyHTMLContext>(
        tag: "form",
        attributes: [
            Attribute(name: "class", value: "feed-form"),
            Attribute(name: "data-form", value: "add-feed")
        ],
        children: [
            // Hidden CSRF token field
            AnyNode(Element<AnyHTMLContext>(
                tag: "input",
                attributes: [
                    Attribute(name: "type", value: "hidden"),
                    Attribute(name: "name", value: "csrf_token"),
                    Attribute(name: "value", value: csrfToken)
                ],
                children: []
            )),
            // ... rest of form
        ]
    )
}
```

#### 3.2 Rate Limiting for Feed Fetching

```swift
public actor FeedService {
    public func fetchFeed(from url: String, feedId: String) async throws -> [Article] {
        // Rate limiter automatically applied by SecureHTTPClient
        // Token bucket: 100 burst, 10/sec sustained

        let data = try await httpClient.get(url: url)
        // ... parsing
    }
}
```

### Phase 4: Testing

#### 4.1 Security Tests
**File**: `Tests/BulletinBoardTests/Security/SecurityIntegrationTests.swift` (NEW)

```swift
import XCTest
@testable import BulletinBoard
import LINKER

final class SecurityIntegrationTests: XCTestCase {

    func testHTMLSanitization() async throws {
        let feedService = FeedService()

        // Test XSS protection
        let maliciousXML = """
        <?xml version="1.0"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>Test</title>
                    <description>&lt;script&gt;alert('XSS')&lt;/script&gt;</description>
                    <link>https://example.com</link>
                </item>
            </channel>
        </rss>
        """

        // Parse should sanitize the script tag
        // ... test
    }

    func testSecureStorage() async throws {
        let storage = StorageService()

        // Test WebAuthn encryption
        let testFeed = Feed(id: "test", title: "Test", url: "https://example.com")
        try await storage.saveFeeds([testFeed])

        let loaded = try await storage.loadFeeds()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, "test")
    }

    func testRateLimiting() async throws {
        // Test rate limiter prevents abuse
        // ... test
    }

    func testCSRFProtection() async throws {
        // Test CSRF tokens are validated
        // ... test
    }
}
```

## Files to Modify

1. ✏️ `Sources/BulletinBoard/Services/FeedService.swift` - Add SecureHTTPClient, HTMLSanitizer
2. ✏️ `Sources/BulletinBoard/Services/StorageService.swift` - Replace with TransparentSecureStorage
3. ✏️ `Sources/BulletinBoard/Components/App.swift` - Initialize security
4. ✏️ `Sources/BulletinBoard/Components/FeedManager.swift` - Add CSRF tokens to forms
5. ➕ `Sources/BulletinBoard/Security/CSPConfiguration.swift` - NEW: CSP headers
6. ➕ `Tests/BulletinBoardTests/Security/SecurityIntegrationTests.swift` - NEW: Security tests

## Migration Strategy

### Option 1: All-at-once (Recommended)
- Enable all security in one PR
- Comprehensive testing
- Breaking change: Requires WebAuthn setup on first run

### Option 2: Gradual
1. Phase 1: HTML sanitization + Secure HTTP (minimal breaking changes)
2. Phase 2: Secure storage (requires WebAuthn setup)
3. Phase 3: CSRF + Rate limiting

## Breaking Changes

### For Users:
1. **First-time setup**: WebAuthn registration required (TouchID/YubiKey/Windows Hello)
   - Fallback: Passphrase-based encryption if WebAuthn unavailable
2. **HTTPS only**: HTTP RSS feeds will be rejected
   - Mitigation: Provide clear error messages
3. **Storage migration**: Existing IndexedDB data needs migration to secure storage
   - Auto-migration script needed

### For Developers:
1. All network requests must use `SecureHTTPClient`
2. All forms need CSRF tokens
3. All storage must use `SecureStorage` or `TransparentSecureStorage`

## Success Criteria

- ✅ All security features enabled and tested
- ✅ Zero XSS vulnerabilities (confirmed by testing)
- ✅ CSRF protection on all state-modifying actions
- ✅ Rate limiting prevents abuse
- ✅ All data encrypted at rest with WebAuthn
- ✅ HTTPS enforced for all external requests
- ✅ CSP headers configured and working
- ✅ Security status dashboard shows "SECURE"
- ✅ All tests passing (including new security tests)

## Timeline Estimate

- Phase 1 (Critical): 2-3 hours (HTML sanitization, Secure HTTP)
- Phase 2 (App Security): 1-2 hours (Security init, CSP)
- Phase 3 (Feed Management): 1 hour (CSRF tokens)
- Phase 4 (Testing): 2 hours (Security tests)
- **Total**: ~6-8 hours of focused development

## Priority: 🔴 CRITICAL

RSS feed readers are **high-risk** applications:
- Parse untrusted external content (XSS risk)
- Store sensitive user data (privacy risk)
- Make external network requests (security risk)

**Recommendation**: Implement security BEFORE public release or user data collection.
