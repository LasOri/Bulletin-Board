import XCTest
@testable import BulletinBoard

final class KeywordExtractorTests: XCTestCase {

    func testExtractBasicKeywords() {
        let text = "Machine learning algorithms are transforming artificial intelligence research. Deep learning neural networks achieve state of the art results."
        let keywords = KeywordExtractor.extract(from: text, maxKeywords: 5)

        XCTAssertFalse(keywords.isEmpty)
        XCTAssertLessThanOrEqual(keywords.count, 5)

        // Should contain multi-word phrases
        let phrases = keywords.map { $0.phrase }
        XCTAssertTrue(phrases.contains(where: { $0.contains("learning") || $0.contains("neural") }))
    }

    func testExtractRespectsMaxKeywords() {
        let text = "Apple banana cherry date elderberry fig grape honeydew kiwi lemon mango nectarine orange papaya quince raspberry strawberry tangerine"
        let keywords = KeywordExtractor.extract(from: text, maxKeywords: 3)
        XCTAssertLessThanOrEqual(keywords.count, 3)
    }

    func testExtractEmptyText() {
        let keywords = KeywordExtractor.extract(from: "")
        XCTAssertTrue(keywords.isEmpty)
    }

    func testExtractStopWordsOnly() {
        let keywords = KeywordExtractor.extract(from: "the and is of to in for")
        XCTAssertTrue(keywords.isEmpty)
    }

    func testScoresArePositive() {
        let text = "Software engineering practices improve code quality and developer productivity."
        let keywords = KeywordExtractor.extract(from: text)
        for keyword in keywords {
            XCTAssertGreaterThan(keyword.score, 0)
        }
    }

    func testScoresAreSortedDescending() {
        let text = "Natural language processing enables computers to understand human language. Text analysis and sentiment detection are key applications of natural language processing."
        let keywords = KeywordExtractor.extract(from: text)
        for i in 1..<keywords.count {
            XCTAssertGreaterThanOrEqual(keywords[i - 1].score, keywords[i].score)
        }
    }

    func testExtractStripsHTML() {
        let text = "<p>Cloud <b>computing</b> services provide scalable infrastructure.</p>"
        let keywords = KeywordExtractor.extract(from: text)
        XCTAssertFalse(keywords.isEmpty)
        let phrases = keywords.map { $0.phrase }
        XCTAssertTrue(phrases.contains(where: { $0.contains("cloud") || $0.contains("computing") }))
    }
}
