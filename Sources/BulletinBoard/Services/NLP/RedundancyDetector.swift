import LINKER

public struct RedundancyDetector: Sendable {

    public let similarityThreshold: Double

    public struct DuplicateGroup: Equatable, Sendable {
        public let originalId: String
        public let duplicateIds: [String]

        public init(originalId: String, duplicateIds: [String]) {
            self.originalId = originalId
            self.duplicateIds = duplicateIds
        }
    }

    public init(similarityThreshold: Double = 0.85) {
        self.similarityThreshold = similarityThreshold
    }

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

