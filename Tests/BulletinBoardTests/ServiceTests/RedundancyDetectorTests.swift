import XCTest
@testable import BulletinBoard

final class RedundancyDetectorTests: XCTestCase {

    func testFindDuplicatesWithSimilarArticles() async {
        let engine = TFIDFEngine()
        let detector = RedundancyDetector(similarityThreshold: 0.5)

        // Index near-duplicate articles
        await engine.indexDocuments([
            (id: "1", text: "Apple releases new iPhone with improved camera and faster processor chip"),
            (id: "2", text: "Apple launches new iPhone featuring better camera and faster processor"),
            (id: "3", text: "Global climate summit addresses carbon emissions and renewable energy targets")
        ])

        let groups = await detector.findDuplicates(
            using: engine,
            articleIds: ["1", "2", "3"]
        )

        // Articles 1 and 2 should be grouped together
        let hasDuplicatePair = groups.contains { group in
            (group.originalId == "1" && group.duplicateIds.contains("2")) ||
            (group.originalId == "2" && group.duplicateIds.contains("1"))
        }
        XCTAssertTrue(hasDuplicatePair, "Near-duplicate articles should be detected")

        // Article 3 should not be grouped with 1 or 2
        let article3InGroup = groups.contains { group in
            group.originalId == "3" || group.duplicateIds.contains("3")
        }
        // Could be false or in its own group - just verify it's not grouped with tech articles
        if article3InGroup {
            for group in groups {
                if group.originalId == "3" {
                    XCTAssertFalse(group.duplicateIds.contains("1"))
                    XCTAssertFalse(group.duplicateIds.contains("2"))
                }
            }
        }
    }

    func testNoDuplicatesForDissimilarArticles() async {
        let engine = TFIDFEngine()
        let detector = RedundancyDetector(similarityThreshold: 0.85)

        await engine.indexDocuments([
            (id: "1", text: "Advanced quantum computing research breakthrough in physics laboratory"),
            (id: "2", text: "Italian pasta recipe with fresh tomatoes and basil cooking instructions"),
            (id: "3", text: "Professional basketball championship tournament playoff results")
        ])

        let groups = await detector.findDuplicates(
            using: engine,
            articleIds: ["1", "2", "3"]
        )

        XCTAssertTrue(groups.isEmpty, "Dissimilar articles should not be grouped as duplicates")
    }

    func testEmptyInput() async {
        let engine = TFIDFEngine()
        let detector = RedundancyDetector()

        let groups = await detector.findDuplicates(using: engine, articleIds: [])
        XCTAssertTrue(groups.isEmpty)
    }

    func testDefaultThreshold() {
        let detector = RedundancyDetector()
        XCTAssertEqual(detector.similarityThreshold, 0.85)
    }

    func testCustomThreshold() {
        let detector = RedundancyDetector(similarityThreshold: 0.7)
        XCTAssertEqual(detector.similarityThreshold, 0.7)
    }
}
