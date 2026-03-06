import Foundation

/// Detects near-duplicate articles using TF-IDF cosine similarity.
public struct RedundancyDetector: Sendable {

    /// Similarity threshold above which articles are considered duplicates.
    public let similarityThreshold: Double

    /// A group of duplicate articles.
    public struct DuplicateGroup: Equatable, Sendable {
        /// The original (first-seen) article ID.
        public let originalId: String
        /// IDs of articles that are near-duplicates of the original.
        public let duplicateIds: [String]

        public init(originalId: String, duplicateIds: [String]) {
            self.originalId = originalId
            self.duplicateIds = duplicateIds
        }
    }

    public init(similarityThreshold: Double = 0.85) {
        self.similarityThreshold = similarityThreshold
    }

    /// Find duplicate groups among a set of articles.
    /// - Parameters:
    ///   - engine: TF-IDF engine with indexed documents
    ///   - articleIds: Article IDs to check
    /// - Returns: Array of duplicate groups
    public func findDuplicates(using engine: TFIDFEngine, articleIds: [String]) async -> [DuplicateGroup] {
        var assigned: Set<String> = []
        var groups: [DuplicateGroup] = []

        for id in articleIds {
            guard !assigned.contains(id) else { continue }

            let similar = await engine.findSimilar(
                to: id,
                limit: articleIds.count,
                threshold: similarityThreshold
            )

            let duplicateIds = similar
                .map { $0.id }
                .filter { articleIds.contains($0) && !assigned.contains($0) }

            if !duplicateIds.isEmpty {
                assigned.insert(id)
                assigned.formUnion(duplicateIds)
                groups.append(DuplicateGroup(originalId: id, duplicateIds: duplicateIds))
            }
        }

        return groups
    }
}
