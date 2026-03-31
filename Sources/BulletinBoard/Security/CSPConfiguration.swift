import LINKER

public struct CSPConfiguration {

    public static func configure() -> String {
        return CSPBuilder()
            .addDirective(.defaultSrc, sources: [.selfOrigin])
            .addDirective(.scriptSrc, sources: [.selfOrigin, .unsafeInline])
            .addDirective(.styleSrc, sources: [.selfOrigin, .unsafeInline])
            .addDirective(.imgSrc, sources: [.selfOrigin, .scheme("data"), .scheme("blob"), .scheme("https")])
            .addDirective(.connectSrc, sources: [.selfOrigin, .scheme("https")])
            .addDirective(.fontSrc, sources: [.selfOrigin, .scheme("data")])
            .addDirective(.objectSrc, sources: [.none])
            .addDirective(.baseUri, sources: [.selfOrigin])
            .addDirective(.formAction, sources: [.selfOrigin])
            .addDirective(.frameAncestors, sources: [.none])
            .addDirective(.upgradeInsecureRequests, sources: [])
            .build()
    }

    #if canImport(JavaScriptKit) && arch(wasm32)
    public static func apply() {
        guard let document = SafeJSGlobal.global?.document else {
            print("⚠️ Cannot apply CSP: document not available")
            return
        }

        guard let metaTag = (try? document.object?.throwing.createElement?("meta"))?.object else {
            print("⚠️ Cannot create CSP meta tag")
            return
        }

        _ = try? metaTag.throwing.setAttribute?("http-equiv", "Content-Security-Policy")
        _ = try? metaTag.throwing.setAttribute?("content", configure())

        guard let head = document.head.object else {
            print("⚠️ Cannot access document head")
            return
        }

        _ = try? head.throwing.appendChild?(metaTag)
        print("✅ CSP applied via meta tag")
    }
    #endif

    public static func printPolicy() {
        print("🛡️  Content Security Policy:")
        print(configure())
    }
}

