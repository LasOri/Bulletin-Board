import XCTest
@testable import BulletinBoard

final class ArticleCategorizerTests: XCTestCase {

    func testClassifyTechnologyArticle() async {
        let engine = TFIDFEngine()
        let categorizer = ArticleCategorizer()

        await engine.indexDocuments([
            (id: "1", text: "New software startup launches cloud computing API for developers. The programming platform uses advanced algorithms."),
            (id: "2", text: "Local team wins championship game after intense playoff match.")
        ])

        let category = await categorizer.classify(
            text: "New software startup launches cloud computing API for developers",
            using: engine
        )
        XCTAssertEqual(category, .technology)
    }

    func testClassifySportsArticle() async {
        let engine = TFIDFEngine()
        let categorizer = ArticleCategorizer()

        await engine.indexDocuments([
            (id: "1", text: "The basketball team won the championship game in the final match of the season tournament."),
            (id: "2", text: "New research study discovers protein molecule in laboratory experiment.")
        ])

        let category = await categorizer.classify(
            text: "The basketball team won the championship game in the final match",
            using: engine
        )
        XCTAssertEqual(category, .sports)
    }

    func testClassifyHealthArticle() async {
        let engine = TFIDFEngine()
        let categorizer = ArticleCategorizer()

        await engine.indexDocuments([
            (id: "1", text: "Clinical trial shows vaccine treatment reduces disease symptoms in hospital patients. Medical researchers publish drug therapy results.")
        ])

        let category = await categorizer.classify(
            text: "Clinical trial shows vaccine treatment reduces disease symptoms in hospital patients",
            using: engine
        )
        XCTAssertEqual(category, .health)
    }

    func testClassifyReturnsOtherForAmbiguous() async {
        let engine = TFIDFEngine()
        let categorizer = ArticleCategorizer(threshold: 0.99)

        await engine.indexDocuments([
            (id: "1", text: "Lorem ipsum dolor sit amet consectetur adipiscing elit")
        ])

        let category = await categorizer.classify(
            text: "Lorem ipsum dolor sit amet",
            using: engine
        )
        XCTAssertEqual(category, .other)
    }

    func testCategorySeedsAreNotEmpty() {
        for (category, seeds) in ArticleCategorizer.categorySeeds {
            XCTAssertFalse(seeds.isEmpty, "Seeds for \(category) should not be empty")
            XCTAssertGreaterThanOrEqual(seeds.count, 15, "Seeds for \(category) should have at least 15 words")
        }
    }

    func testAllCategoriesHaveSeeds() {
        for category in ArticleCategory.allCases where category != .other {
            XCTAssertNotNil(
                ArticleCategorizer.categorySeeds[category],
                "Category \(category) should have seed words"
            )
        }
    }
}
