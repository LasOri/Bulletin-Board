import Testing
@testable import BulletinBoard

@Suite("String strippingHTML")
struct StringStrippingHTMLTests {

    @Test func stripsSimpleTags() {
        let input = "<p>Hello <strong>world</strong></p>"
        let result = input.strippingHTML()
        #expect(result == "Hello world")
    }

    @Test func stripsAnchorTags() {
        let input = #"<a href="https://example.com">Click here</a>"#
        let result = input.strippingHTML()
        #expect(result == "Click here")
    }

    @Test func handlesHTMLEntities() {
        let input = "Tom &amp; Jerry &lt;3 &quot;fun&quot;"
        let result = input.strippingHTML()
        #expect(result == #"Tom & Jerry <3 "fun""#)
    }

    @Test func handlesHexEntities() {
        let input = "https:&#x2F;&#x2F;example.com&#x2F;path"
        let result = input.strippingHTML()
        #expect(result == "https://example.com/path")
    }

    @Test func collapsesWhitespace() {
        let input = "<p>Hello</p>   <p>World</p>"
        let result = input.strippingHTML()
        #expect(result == "Hello World")
    }

    @Test func returnsPlainTextUnchanged() {
        let input = "Just plain text"
        let result = input.strippingHTML()
        #expect(result == "Just plain text")
    }

    @Test func handlesHackerNewsDescription() {
        let input = #"<p>Article URL: <a href="https://example.com/article">https://example.com/article</a></p> <p>Comments URL: <a href="https://news.ycombinator.com/item?id=123">https://news.ycombinator.com/item?id=123</a></p> <p>Points: 71</p> <p># Comments: 9</p>"#
        let result = input.strippingHTML()
        #expect(result.contains("Article URL:"))
        #expect(result.contains("https://example.com/article"))
        #expect(result.contains("Points: 71"))
        #expect(!result.contains("<p>"))
        #expect(!result.contains("<a "))
        #expect(!result.contains("</a>"))
    }

    @Test func handlesEmptyString() {
        #expect("".strippingHTML() == "")
    }

    @Test func handlesNbsp() {
        let input = "Hello&nbsp;World"
        #expect(input.strippingHTML() == "Hello World")
    }
}
