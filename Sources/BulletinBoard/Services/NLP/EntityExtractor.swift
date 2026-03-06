import Foundation

/// Extracts named entities using dictionary lookup and regex patterns.
public enum EntityExtractor {

    /// Entity type classification.
    public enum EntityType: String, Sendable, Equatable {
        case person
        case organization
        case location
        case date
        case money
        case email
        case url
    }

    /// An extracted named entity.
    public struct Entity: Equatable, Sendable {
        public let text: String
        public let type: EntityType

        public init(text: String, type: EntityType) {
            self.text = text
            self.type = type
        }
    }

    /// Organization suffixes for dictionary-based detection.
    private static let orgSuffixes = [
        "Inc", "Inc.", "Corp", "Corp.", "LLC", "Ltd", "Ltd.",
        "Co", "Co.", "Group", "Holdings", "Foundation",
        "Association", "Institute", "University", "Bank"
    ]

    /// Person title prefixes for dictionary-based detection.
    private static let personPrefixes = [
        "Mr", "Mr.", "Mrs", "Mrs.", "Ms", "Ms.", "Dr", "Dr.",
        "Prof", "Prof.", "Sen", "Sen.", "Rep", "Rep.",
        "Gov", "Gov.", "Pres", "Pres.", "Gen", "Gen.",
        "Sgt", "Sgt.", "Cpl", "Cpl.", "Rev", "Rev."
    ]

    /// Extract named entities from text.
    /// - Parameter text: Input text
    /// - Returns: Array of extracted entities
    public static func extract(from text: String) -> [Entity] {
        let cleaned = TextProcessor.stripHTML(text)
        var entities: [Entity] = []

        // Regex-based extraction
        entities.append(contentsOf: extractEmails(from: cleaned))
        entities.append(contentsOf: extractURLs(from: cleaned))
        entities.append(contentsOf: extractMoney(from: cleaned))
        entities.append(contentsOf: extractDates(from: cleaned))

        // Dictionary-based extraction
        entities.append(contentsOf: extractOrganizations(from: cleaned))
        entities.append(contentsOf: extractPersons(from: cleaned))

        // Deduplicate
        var seen: Set<String> = []
        return entities.filter { entity in
            let key = "\(entity.type.rawValue):\(entity.text)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    // MARK: - Regex-based extraction

    private static func extractEmails(from text: String) -> [Entity] {
        let pattern = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/
        return text.matches(of: pattern).map {
            Entity(text: String($0.output), type: .email)
        }
    }

    private static func extractURLs(from text: String) -> [Entity] {
        let pattern = /https?:\/\/[^\s<>"{}|\\^`\[\]]+/
        return text.matches(of: pattern).map {
            Entity(text: String($0.output), type: .url)
        }
    }

    private static func extractMoney(from text: String) -> [Entity] {
        let pattern = /\$[\d,]+(?:\.\d{2})?(?:\s*(?:million|billion|trillion))?/
        return text.matches(of: pattern).map {
            Entity(text: String($0.output), type: .money)
        }
    }

    private static func extractDates(from text: String) -> [Entity] {
        var entities: [Entity] = []

        // Month DD, YYYY
        let pattern1 = /(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4}/
        for match in text.matches(of: pattern1) {
            entities.append(Entity(text: String(match.output), type: .date))
        }

        // MM/DD/YYYY or MM-DD-YYYY
        let pattern2 = /\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}/
        for match in text.matches(of: pattern2) {
            entities.append(Entity(text: String(match.output), type: .date))
        }

        return entities
    }

    // MARK: - Dictionary-based extraction

    private static func extractOrganizations(from text: String) -> [Entity] {
        var entities: [Entity] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines)

        for (i, word) in words.enumerated() {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            if orgSuffixes.contains(cleanWord) && i > 0 {
                // Collect preceding capitalized words as org name
                var orgWords: [String] = [cleanWord]
                var j = i - 1
                while j >= 0 {
                    let prev = words[j].trimmingCharacters(in: .punctuationCharacters)
                    if prev.first?.isUppercase == true && prev.count > 1 {
                        orgWords.insert(prev, at: 0)
                        j -= 1
                    } else {
                        break
                    }
                }
                if orgWords.count > 1 {
                    entities.append(Entity(text: orgWords.joined(separator: " "), type: .organization))
                }
            }
        }

        return entities
    }

    private static func extractPersons(from text: String) -> [Entity] {
        var entities: [Entity] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines)

        for (i, word) in words.enumerated() {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            if personPrefixes.contains(cleanWord) || personPrefixes.contains(word) {
                // Collect following capitalized words as person name
                var nameWords: [String] = [cleanWord]
                var j = i + 1
                while j < words.count {
                    let next = words[j].trimmingCharacters(in: .punctuationCharacters)
                    if next.first?.isUppercase == true && next.count > 1 {
                        nameWords.append(next)
                        j += 1
                    } else {
                        break
                    }
                }
                if nameWords.count > 1 {
                    entities.append(Entity(text: nameWords.joined(separator: " "), type: .person))
                }
            }
        }

        return entities
    }
}
