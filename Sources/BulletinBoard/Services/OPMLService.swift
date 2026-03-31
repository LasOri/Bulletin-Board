#if canImport(JavaScriptKit)
import JavaScriptKit
#endif
import LINKER

public struct OPMLService {

    public static func parseOPML(xml: String) -> [(title: String, url: String)] {
        #if canImport(JavaScriptKit) && arch(wasm32)
        guard let domParserConstructor = SafeJSGlobal.global?.DOMParser.function else {
            return []
        }

        let parser = domParserConstructor.new()
        let doc = try? parser.throwing.parseFromString?(xml, "text/xml")

        guard let docObj = doc?.object else { return [] }

        if (try? docObj.throwing.querySelector?("parsererror"))?.object != nil {
            return []
        }

        let outlines = try? docObj.throwing.querySelectorAll?("outline[xmlUrl]")
        guard let collection = outlines?.object else { return [] }

        let length = collection.length.number.map { Int($0) } ?? 0
        var feeds: [(title: String, url: String)] = []

        for i in 0..<length {
            guard let item = (try? collection.throwing.item?(i))?.object else { continue }
            let url = (try? item.throwing.getAttribute?("xmlUrl"))?.string ?? ""
            let title = (try? item.throwing.getAttribute?("text"))?.string
                ?? (try? item.throwing.getAttribute?("title"))?.string
                ?? url
            if !url.isEmpty {
                feeds.append((title: title, url: url))
            }
        }

        return feeds
        #else
        return []
        #endif
    }

    public static func generateOPML(feeds: [Feed]) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
        <head><title>Bulletin Board Feeds</title></head>
        <body>
        """

        for feed in feeds {
            let escapedTitle = escapeXML(feed.title)
            let escapedURL = escapeXML(feed.url)
            let escapedSiteURL = escapeXML(feed.siteUrl ?? "")
            xml += "\n<outline type=\"rss\" text=\"\(escapedTitle)\" title=\"\(escapedTitle)\" xmlUrl=\"\(escapedURL)\" htmlUrl=\"\(escapedSiteURL)\"/>"
        }

        xml += "\n</body>\n</opml>"
        return xml
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingAll("&", with: "&amp;")
            .replacingAll("<", with: "&lt;")
            .replacingAll(">", with: "&gt;")
            .replacingAll("\"", with: "&quot;")
            .replacingAll("'", with: "&apos;")
    }
}
