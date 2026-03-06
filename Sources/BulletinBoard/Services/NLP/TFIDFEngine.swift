import Foundation

/// TF-IDF computation engine for document vectorization and similarity.
///
/// Maintains a corpus of documents and computes TF-IDF vectors
/// that can be compared using cosine similarity.
public actor TFIDFEngine {

    /// Sparse vector representation for TF-IDF document vectors.
    public struct SparseVector: Sendable {
        public let components: [String: Double]

        public init(components: [String: Double]) {
            self.components = components
        }

        /// L2 norm of the vector.
        public var magnitude: Double {
            let sumOfSquares = components.values.reduce(0.0) { $0 + $1 * $1 }
            return sumOfSquares.squareRoot()
        }
    }

    // Corpus-level state
    private var documentFrequency: [String: Int] = [:]
    private var documentCount: Int = 0
    private var documentVectors: [String: SparseVector] = [:]
    private var documentTermFreqs: [String: [String: Int]] = [:]

    public init() {}

    /// Add multiple documents to the corpus.
    /// - Parameter documents: Array of (id, text) tuples
    public func indexDocuments(_ documents: [(id: String, text: String)]) {
        // First pass: compute term frequencies and document frequency
        for (id, text) in documents {
            let tf = TextProcessor.termFrequencies(from: text)
            documentTermFreqs[id] = tf

            // Update document frequency (each term counted once per doc)
            for term in tf.keys {
                documentFrequency[term, default: 0] += 1
            }
            documentCount += 1
        }

        // Second pass: compute TF-IDF vectors
        for (id, _) in documents {
            guard let tf = documentTermFreqs[id] else { continue }
            documentVectors[id] = computeVector(termFreqs: tf)
        }
    }

    /// Add a single document to the corpus.
    /// - Parameters:
    ///   - id: Document identifier
    ///   - text: Document text
    public func indexDocument(id: String, text: String) {
        let tf = TextProcessor.termFrequencies(from: text)
        documentTermFreqs[id] = tf

        for term in tf.keys {
            documentFrequency[term, default: 0] += 1
        }
        documentCount += 1

        documentVectors[id] = computeVector(termFreqs: tf)
    }

    /// Remove a document from the corpus.
    /// - Parameter id: Document identifier to remove
    public func removeDocument(id: String) {
        guard let tf = documentTermFreqs[id] else { return }

        for term in tf.keys {
            if let count = documentFrequency[term] {
                if count <= 1 {
                    documentFrequency.removeValue(forKey: term)
                } else {
                    documentFrequency[term] = count - 1
                }
            }
        }

        documentTermFreqs.removeValue(forKey: id)
        documentVectors.removeValue(forKey: id)
        documentCount -= 1
    }

    /// Get the TF-IDF vector for a document.
    /// - Parameter documentId: Document identifier
    /// - Returns: Sparse vector or nil if not indexed
    public func vector(for documentId: String) -> SparseVector? {
        documentVectors[documentId]
    }

    /// Compute a TF-IDF vector for arbitrary text using current corpus IDF.
    /// - Parameter text: Input text
    /// - Returns: Sparse TF-IDF vector
    public func vectorize(text: String) -> SparseVector {
        let tf = TextProcessor.termFrequencies(from: text)
        return computeVector(termFreqs: tf)
    }

    /// Cosine similarity between two sparse vectors.
    /// - Returns: Value in [0, 1] where 1 means identical direction
    public static func cosineSimilarity(_ a: SparseVector, _ b: SparseVector) -> Double {
        let magA = a.magnitude
        let magB = b.magnitude
        guard magA > 0 && magB > 0 else { return 0.0 }

        // Dot product — iterate over the smaller vector
        let (smaller, larger) = a.components.count <= b.components.count
            ? (a.components, b.components)
            : (b.components, a.components)

        var dot = 0.0
        for (term, valueA) in smaller {
            if let valueB = larger[term] {
                dot += valueA * valueB
            }
        }

        return dot / (magA * magB)
    }

    /// Find top-N most similar documents to a given document.
    /// - Parameters:
    ///   - documentId: Reference document
    ///   - limit: Maximum results (default: 5)
    ///   - threshold: Minimum similarity to include (default: 0.1)
    /// - Returns: Array of (id, similarity) sorted by similarity descending
    public func findSimilar(to documentId: String, limit: Int = 5, threshold: Double = 0.1) -> [(id: String, similarity: Double)] {
        guard let refVector = documentVectors[documentId] else { return [] }

        var results: [(id: String, similarity: Double)] = []

        for (id, vector) in documentVectors where id != documentId {
            let sim = Self.cosineSimilarity(refVector, vector)
            if sim >= threshold {
                results.append((id: id, similarity: sim))
            }
        }

        return results
            .sorted { $0.similarity > $1.similarity }
            .prefix(limit)
            .map { $0 }
    }

    /// Clear all state.
    public func clear() {
        documentFrequency.removeAll()
        documentCount = 0
        documentVectors.removeAll()
        documentTermFreqs.removeAll()
    }

    /// Number of documents in the corpus.
    public var count: Int { documentCount }

    // MARK: - Private

    private func computeVector(termFreqs: [String: Int]) -> SparseVector {
        guard documentCount > 0 else { return SparseVector(components: [:]) }

        var components: [String: Double] = [:]
        let totalTerms = termFreqs.values.reduce(0, +)
        guard totalTerms > 0 else { return SparseVector(components: [:]) }

        for (term, count) in termFreqs {
            let tf = Double(count) / Double(totalTerms)
            let df = documentFrequency[term, default: 1]
            let idf = log(Double(documentCount + 1) / Double(df + 1)) + 1.0
            components[term] = tf * idf
        }

        return SparseVector(components: components)
    }
}
