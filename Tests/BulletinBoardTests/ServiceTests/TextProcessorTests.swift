import XCTest
@testable import BulletinBoard

final class TextProcessorTests: XCTestCase {

    // MARK: - extractTerms

    func testExtractTermsBasic() {
        let terms = TextProcessor.extractTerms(from: "The quick brown fox jumps over the lazy dog")
        XCTAssertTrue(terms.contains("quick"))
        XCTAssertTrue(terms.contains("brown"))
        XCTAssertTrue(terms.contains("fox"))
        XCTAssertTrue(terms.contains("jumps"))
        XCTAssertTrue(terms.contains("lazy"))
        XCTAssertTrue(terms.contains("dog"))
        // Stop words should be removed
        XCTAssertFalse(terms.contains("the"))
        XCTAssertFalse(terms.contains("over"))
    }

    func testExtractTermsRemovesShortWords() {
        let terms = TextProcessor.extractTerms(from: "I am a go to it")
        XCTAssertTrue(terms.isEmpty)
    }

    func testExtractTermsMinLength() {
        let terms = TextProcessor.extractTerms(from: "cat dog bird elephant", minLength: 4)
        XCTAssertFalse(terms.contains("cat"))
        XCTAssertFalse(terms.contains("dog"))
        XCTAssertTrue(terms.contains("bird"))
        XCTAssertTrue(terms.contains("elephant"))
    }

    func testExtractTermsLowercases() {
        let terms = TextProcessor.extractTerms(from: "HELLO World SwIfT")
        XCTAssertTrue(terms.contains("hello"))
        XCTAssertTrue(terms.contains("world"))
        XCTAssertTrue(terms.contains("swift"))
    }

    func testExtractTermsStripsPunctuation() {
        let terms = TextProcessor.extractTerms(from: "hello, world! swift.")
        XCTAssertTrue(terms.contains("hello"))
        XCTAssertTrue(terms.contains("world"))
        XCTAssertTrue(terms.contains("swift"))
    }

    func testExtractTermsStripsHTML() {
        let terms = TextProcessor.extractTerms(from: "<p>Hello <b>World</b></p>")
        XCTAssertTrue(terms.contains("hello"))
        XCTAssertTrue(terms.contains("world"))
    }

    // MARK: - termFrequencies

    func testTermFrequencies() {
        let freqs = TextProcessor.termFrequencies(from: "apple banana apple cherry apple banana")
        XCTAssertEqual(freqs["apple"], 3)
        XCTAssertEqual(freqs["banana"], 2)
        XCTAssertEqual(freqs["cherry"], 1)
    }

    func testTermFrequenciesEmpty() {
        let freqs = TextProcessor.termFrequencies(from: "")
        XCTAssertTrue(freqs.isEmpty)
    }

    // MARK: - sentences

    func testSentenceSplitting() {
        let sents = TextProcessor.sentences(from: "Hello world. How are you? I'm fine!")
        XCTAssertEqual(sents.count, 3)
        XCTAssertEqual(sents[0], "Hello world.")
        XCTAssertEqual(sents[1], "How are you?")
        XCTAssertEqual(sents[2], "I'm fine!")
    }

    func testSentenceSplittingNoTerminator() {
        let sents = TextProcessor.sentences(from: "No period at the end")
        XCTAssertEqual(sents.count, 1)
        XCTAssertEqual(sents[0], "No period at the end")
    }

    // MARK: - stripHTML

    func testStripHTML() {
        let result = TextProcessor.stripHTML("<p>Hello <b>World</b></p>")
        XCTAssertEqual(result, "Hello World")
    }

    func testStripHTMLEntities() {
        let result = TextProcessor.stripHTML("Tom &amp; Jerry &lt;3")
        XCTAssertEqual(result, "Tom & Jerry <3")
    }

    func testStripHTMLPlainText() {
        let result = TextProcessor.stripHTML("No tags here")
        XCTAssertEqual(result, "No tags here")
    }

    // MARK: - stopWords

    func testStopWordsContainsCommonWords() {
        XCTAssertTrue(TextProcessor.stopWords.contains("the"))
        XCTAssertTrue(TextProcessor.stopWords.contains("and"))
        XCTAssertTrue(TextProcessor.stopWords.contains("is"))
        XCTAssertTrue(TextProcessor.stopWords.contains("of"))
        XCTAssertTrue(TextProcessor.stopWords.contains("for"))
    }
}
