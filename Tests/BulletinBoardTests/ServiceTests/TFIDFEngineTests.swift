import XCTest
@testable import BulletinBoard

final class TFIDFEngineTests: XCTestCase {

    // MARK: - Basic indexing

    func testIndexDocuments() async {
        let engine = TFIDFEngine()
        await engine.indexDocuments([
            (id: "1", text: "The cat sat on the mat"),
            (id: "2", text: "The dog played in the park"),
            (id: "3", text: "The cat chased the dog")
        ])
        let count = await engine.count
        XCTAssertEqual(count, 3)
    }

    func testIndexSingleDocument() async {
        let engine = TFIDFEngine()
        await engine.indexDocument(id: "doc1", text: "Swift programming language")
        let vec = await engine.vector(for: "doc1")
        XCTAssertNotNil(vec)
        XCTAssertFalse(vec!.components.isEmpty)
    }

    func testRemoveDocument() async {
        let engine = TFIDFEngine()
        await engine.indexDocument(id: "doc1", text: "Swift programming")
        await engine.removeDocument(id: "doc1")
        let vec = await engine.vector(for: "doc1")
        XCTAssertNil(vec)
        let count = await engine.count
        XCTAssertEqual(count, 0)
    }

    // MARK: - Cosine similarity

    func testCosineSimilarityIdentical() {
        let vec = TFIDFEngine.SparseVector(components: ["a": 1.0, "b": 2.0])
        let sim = TFIDFEngine.cosineSimilarity(vec, vec)
        XCTAssertEqual(sim, 1.0, accuracy: 0.001)
    }

    func testCosineSimilarityOrthogonal() {
        let a = TFIDFEngine.SparseVector(components: ["x": 1.0])
        let b = TFIDFEngine.SparseVector(components: ["y": 1.0])
        let sim = TFIDFEngine.cosineSimilarity(a, b)
        XCTAssertEqual(sim, 0.0, accuracy: 0.001)
    }

    func testCosineSimilarityPartialOverlap() {
        let a = TFIDFEngine.SparseVector(components: ["x": 1.0, "y": 1.0])
        let b = TFIDFEngine.SparseVector(components: ["y": 1.0, "z": 1.0])
        let sim = TFIDFEngine.cosineSimilarity(a, b)
        // dot = 1, |a| = sqrt(2), |b| = sqrt(2), sim = 1/2 = 0.5
        XCTAssertEqual(sim, 0.5, accuracy: 0.001)
    }

    func testCosineSimilarityEmptyVector() {
        let a = TFIDFEngine.SparseVector(components: [:])
        let b = TFIDFEngine.SparseVector(components: ["x": 1.0])
        let sim = TFIDFEngine.cosineSimilarity(a, b)
        XCTAssertEqual(sim, 0.0)
    }

    // MARK: - Find similar

    func testFindSimilar() async {
        let engine = TFIDFEngine()
        await engine.indexDocuments([
            (id: "1", text: "Machine learning algorithms for data science"),
            (id: "2", text: "Deep learning neural network algorithms"),
            (id: "3", text: "Cooking recipes for Italian pasta dishes")
        ])

        let similar = await engine.findSimilar(to: "1", limit: 5, threshold: 0.0)
        XCTAssertFalse(similar.isEmpty)

        // Doc 2 should be more similar to doc 1 than doc 3
        if let sim2 = similar.first(where: { $0.id == "2" }),
           let sim3 = similar.first(where: { $0.id == "3" }) {
            XCTAssertGreaterThan(sim2.similarity, sim3.similarity)
        }
    }

    // MARK: - Vectorize

    func testVectorizeArbitraryText() async {
        let engine = TFIDFEngine()
        await engine.indexDocuments([
            (id: "1", text: "Swift programming language"),
            (id: "2", text: "Python programming language")
        ])

        let vec = await engine.vectorize(text: "Swift code programming")
        XCTAssertFalse(vec.components.isEmpty)
    }

    // MARK: - Clear

    func testClear() async {
        let engine = TFIDFEngine()
        await engine.indexDocument(id: "1", text: "Hello world")
        await engine.clear()
        let count = await engine.count
        XCTAssertEqual(count, 0)
    }

    // MARK: - SparseVector

    func testSparseVectorMagnitude() {
        let vec = TFIDFEngine.SparseVector(components: ["a": 3.0, "b": 4.0])
        XCTAssertEqual(vec.magnitude, 5.0, accuracy: 0.001)
    }

    func testSparseVectorEmptyMagnitude() {
        let vec = TFIDFEngine.SparseVector(components: [:])
        XCTAssertEqual(vec.magnitude, 0.0)
    }
}
