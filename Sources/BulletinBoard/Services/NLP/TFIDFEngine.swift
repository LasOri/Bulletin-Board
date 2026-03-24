import Foundation

public actor TFIDFEngine {

    public struct SparseVector: Sendable {
        public let components: [String: Double]

        public init(components: [String: Double]) {
            self.components = components
        }

        public var magnitude: Double {
            let sumOfSquares = components.values.reduce(0.0) { $0 + $1 * $1 }
            return sumOfSquares.squareRoot()
        }
    }

    private var documentFrequency: [String: Int] = [:]
    private var documentCount: Int = 0
    private var documentVectors: [String: SparseVector] = [:]
    private var documentTermFreqs: [String: [String: Int]] = [:]

    public init() {}

    public func indexDocuments(_ documents: [(id: String, text: String)]) {
        for (id, text) in documents {
            let tf = TextProcessor.termFrequencies(from: text)
            documentTermFreqs[id] = tf

            for term in tf.keys {
                documentFrequency[term, default: 0] += 1
            }
            documentCount += 1
        }

        for (id, _) in documents {
            guard let tf = documentTermFreqs[id] else { continue }
            documentVectors[id] = computeVector(termFreqs: tf)
        }
    }

    public func indexDocument(id: String, text: String) {
        let tf = TextProcessor.termFrequencies(from: text)
        documentTermFreqs[id] = tf

        for term in tf.keys {
            documentFrequency[term, default: 0] += 1
        }
        documentCount += 1

        documentVectors[id] = computeVector(termFreqs: tf)
    }

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

    public func vector(for documentId: String) -> SparseVector? {
        documentVectors[documentId]
    }

    public func vectorize(text: String) -> SparseVector {
        let tf = TextProcessor.termFrequencies(from: text)
        return computeVector(termFreqs: tf)
    }

    public static func cosineSimilarity(_ a: SparseVector, _ b: SparseVector) -> Double {
        let magA = a.magnitude
        let magB = b.magnitude
        guard magA > 0 && magB > 0 else { return 0.0 }

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

    public func clear() {
        documentFrequency.removeAll()
        documentCount = 0
        documentVectors.removeAll()
        documentTermFreqs.removeAll()
    }

    public var count: Int { documentCount }

    public var indexedDocumentIds: Set<String> {
        Set(documentVectors.keys)
    }

    public func indexDocumentIfNew(id: String, text: String) {
        guard documentVectors[id] == nil else { return }
        indexDocument(id: id, text: text)
    }

    public func pairwiseSimilarities(
        newIds: [String],
        existingIds: [String],
        threshold: Double = 0.15,
        maxComparisons: Int = 50
    ) -> [(id1: String, id2: String, similarity: Double)] {
        var results: [(id1: String, id2: String, similarity: Double)] = []
        let compareAgainst = existingIds.suffix(maxComparisons)

        for newId in newIds {
            guard let newVec = documentVectors[newId] else { continue }
            for existingId in compareAgainst where existingId != newId {
                guard let existingVec = documentVectors[existingId] else { continue }
                let sim = Self.cosineSimilarity(newVec, existingVec)
                if sim >= threshold {
                    results.append((id1: newId, id2: existingId, similarity: sim))
                }
            }
        }

        for i in 0..<newIds.count {
            guard let vecI = documentVectors[newIds[i]] else { continue }
            for j in (i + 1)..<newIds.count {
                guard let vecJ = documentVectors[newIds[j]] else { continue }
                let sim = Self.cosineSimilarity(vecI, vecJ)
                if sim >= threshold {
                    results.append((id1: newIds[i], id2: newIds[j], similarity: sim))
                }
            }
        }

        return results
    }

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

