import LINKER

public enum EntityExtractor {

    public enum EntityType: String, Sendable, Equatable {
        case person
        case organization
        case location
        case date
        case money
        case email
        case url
    }

    public struct Entity: Equatable, Sendable {
        public let text: String
        public let type: EntityType

        public init(text: String, type: EntityType) {
            self.text = text
            self.type = type
        }
    }

    private static let orgSuffixes = [
        "Inc", "Inc.", "Corp", "Corp.", "LLC", "Ltd", "Ltd.",
        "Co", "Co.", "Group", "Holdings", "Foundation",
        "Association", "Institute", "University", "Bank"
    ]

    private static let personPrefixes = [
        "Mr", "Mr.", "Mrs", "Mrs.", "Ms", "Ms.", "Dr", "Dr.",
        "Prof", "Prof.", "Sen", "Sen.", "Rep", "Rep.",
        "Gov", "Gov.", "Pres", "Pres.", "Gen", "Gen.",
        "Sgt", "Sgt.", "Cpl", "Cpl.", "Rev", "Rev."
    ]

    public static func extract(from text: String) -> [Entity] {
        let cleaned = TextProcessor.stripHTML(text)
        var entities: [Entity] = []

        entities.append(contentsOf: extractEmails(from: cleaned))
        entities.append(contentsOf: extractURLs(from: cleaned))
        entities.append(contentsOf: extractMoney(from: cleaned))
        entities.append(contentsOf: extractDates(from: cleaned))

        entities.append(contentsOf: extractOrganizations(from: cleaned))
        entities.append(contentsOf: extractPersons(from: cleaned))

        var seen: Set<String> = []
        return entities.filter { entity in
            let key = "\(entity.type.rawValue):\(entity.text)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

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

        let pattern1 = /(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4}/
        for match in text.matches(of: pattern1) {
            entities.append(Entity(text: String(match.output), type: .date))
        }

        let pattern2 = /\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}/
        for match in text.matches(of: pattern2) {
            entities.append(Entity(text: String(match.output), type: .date))
        }

        return entities
    }

    private static func extractOrganizations(from text: String) -> [Entity] {
        var entities: [Entity] = []
        let words = text.splitByWhitespace()

        for (i, word) in words.enumerated() {
            let cleanWord = word.trimmingPunctuation()
            if orgSuffixes.contains(cleanWord) && i > 0 {
                var orgWords: [String] = [cleanWord]
                var j = i - 1
                while j >= 0 {
                    let prev = words[j].trimmingPunctuation()
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
        let words = text.splitByWhitespace()

        for (i, word) in words.enumerated() {
            let cleanWord = word.trimmingPunctuation()
            if personPrefixes.contains(cleanWord) || personPrefixes.contains(word) {
                var nameWords: [String] = [cleanWord]
                var j = i + 1
                while j < words.count {
                    let next = words[j].trimmingPunctuation()
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
