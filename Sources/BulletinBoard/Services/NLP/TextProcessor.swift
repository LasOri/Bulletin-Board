import Foundation

public enum TextProcessor {

    public static let stopWords: Set<String> = [
        "a", "about", "above", "after", "again", "against", "all", "am", "an",
        "and", "any", "are", "aren't", "as", "at", "be", "because", "been",
        "before", "being", "below", "between", "both", "but", "by", "can",
        "could", "did", "do", "does", "doing", "don't", "down", "during",
        "each", "few", "for", "from", "further", "get", "got", "had", "has",
        "have", "having", "he", "her", "here", "hers", "herself", "him",
        "himself", "his", "how", "i", "if", "in", "into", "is", "isn't",
        "it", "its", "itself", "just", "let", "me", "might", "more", "most",
        "must", "my", "myself", "no", "nor", "not", "now", "of", "off", "on",
        "once", "only", "or", "other", "our", "ours", "ourselves", "out",
        "over", "own", "re", "s", "said", "same", "say", "she", "should",
        "so", "some", "such", "t", "than", "that", "the", "their", "theirs",
        "them", "themselves", "then", "there", "these", "they", "this",
        "those", "through", "to", "too", "under", "until", "up", "us",
        "very", "was", "wasn't", "we", "were", "what", "when", "where",
        "which", "while", "who", "whom", "why", "will", "with", "won't",
        "would", "you", "your", "yours", "yourself", "yourselves"
    ]

    public static func extractTerms(from text: String, minLength: Int = 3) -> [String] {
        let cleaned = stripHTML(text)
        return cleaned
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && $0.count >= minLength && !stopWords.contains($0) }
    }

    public static func termFrequencies(from text: String) -> [String: Int] {
        let terms = extractTerms(from: text)
        var frequencies: [String: Int] = [:]
        for term in terms {
            frequencies[term, default: 0] += 1
        }
        return frequencies
    }

    public static func sentences(from text: String) -> [String] {
        let cleaned = stripHTML(text)
        var results: [String] = []
        var current = ""

        for char in cleaned {
            current.append(char)
            if char == "." || char == "!" || char == "?" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    results.append(trimmed)
                }
                current = ""
            }
        }

        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            results.append(trimmed)
        }

        return results
    }

    public static func stripHTML(_ text: String) -> String {
        var result = text
        while let openRange = result.range(of: "<"),
              let closeRange = result.range(of: ">", range: openRange.upperBound..<result.endIndex) {
            result.removeSubrange(openRange.lowerBound...closeRange.lowerBound)
        }
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result
    }
}

