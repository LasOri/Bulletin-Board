import Foundation
import LINKER

/// Content Security Policy configuration for Bulletin Board.
///
/// Provides defense-in-depth protection against XSS and other injection attacks
/// by restricting sources of content that can be loaded.
public struct CSPConfiguration {

    /// Builds a strict Content Security Policy for Bulletin Board.
    ///
    /// # Policy Details:
    /// - **default-src 'self'**: Only allow resources from same origin by default
    /// - **script-src 'self' 'unsafe-inline'**: Allow WASM and inline scripts
    /// - **style-src 'self' 'unsafe-inline'**: Allow inline styles for dynamic styling
    /// - **img-src 'self' data: https:**: Allow images from feeds and data URLs
    /// - **connect-src 'self' https:**: Allow HTTPS connections to RSS feeds
    /// - **font-src 'self' data:**: Allow web fonts
    /// - **object-src 'none'**: Block plugins (Flash, Java, etc.)
    /// - **base-uri 'self'**: Prevent base tag hijacking
    /// - **form-action 'self'**: Only allow forms to submit to same origin
    /// - **frame-ancestors 'none'**: Prevent clickjacking
    /// - **upgrade-insecure-requests**: Upgrade HTTP to HTTPS
    ///
    /// # Returns:
    /// CSP header string ready for HTTP response
    public static func configure() -> String {
        return CSPBuilder()
            .addDirective(.defaultSrc, sources: [.selfOrigin])
            .addDirective(.scriptSrc, sources: [.selfOrigin, .unsafeInline])
            .addDirective(.styleSrc, sources: [.selfOrigin, .unsafeInline])
            .addDirective(.imgSrc, sources: [.selfOrigin, .scheme("data"), .scheme("https")])
            .addDirective(.connectSrc, sources: [.selfOrigin, .scheme("https")])
            .addDirective(.fontSrc, sources: [.selfOrigin, .scheme("data")])
            .addDirective(.objectSrc, sources: [.none])
            .addDirective(.baseUri, sources: [.selfOrigin])
            .addDirective(.formAction, sources: [.selfOrigin])
            .addDirective(.frameAncestors, sources: [.none])
            .addDirective(.upgradeInsecureRequests, sources: [])
            .build()
    }

    /// Applies the CSP configuration to the current page.
    ///
    /// Note: In a real web app, CSP headers should be set by the server.
    /// This method is for client-side meta tag injection (fallback).
    #if canImport(JavaScriptKit) && arch(wasm32)
    public static func apply() {
        guard let document = SafeJSGlobal.global?.document else {
            print("⚠️ Cannot apply CSP: document not available")
            return
        }

        // Create CSP meta tag
        guard let metaTag = document.createElement("meta").object else {
            print("⚠️ Cannot create CSP meta tag")
            return
        }

        metaTag.setAttribute("http-equiv", "Content-Security-Policy")
        metaTag.setAttribute("content", configure())

        // Add to document head
        guard let head = document.head.object,
              let appendChild = head.appendChild.function else {
            print("⚠️ Cannot access document head")
            return
        }

        _ = appendChild(metaTag)
        print("✅ CSP applied via meta tag")
    }
    #endif

    /// Prints the configured CSP policy for debugging.
    public static func printPolicy() {
        print("🛡️  Content Security Policy:")
        print(configure())
    }
}
