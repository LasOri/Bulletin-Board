import Foundation

/// Shared text processing utilities for NLP algorithms.
///
/// Provides tokenization, stop word filtering, sentence splitting,
/// and HTML stripping used across all NLP components.
public enum TextProcessor {

    /// Common English stop words (expanded set)
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

    /// Tokenize text into lowercase terms, removing punctuation and stop words.
    /// - Parameters:
    ///   - text: Input text to tokenize
    ///   - minLength: Minimum term length (default: 3)
    /// - Returns: Array of filtered terms
    public static func extractTerms(from text: String, minLength: Int = 3) -> [String] {
        let cleaned = stripHTML(text)
        return cleaned
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && $0.count >= minLength && !stopWords.contains($0) }
    }

    /// Extract terms preserving frequency counts (for TF-IDF).
    /// - Parameter text: Input text
    /// - Returns: Dictionary of term → count
    public static func termFrequencies(from text: String) -> [String: Int] {
        let terms = extractTerms(from: text)
        var frequencies: [String: Int] = [:]
        for term in terms {
            frequencies[term, default: 0] += 1
        }
        return frequencies
    }

    /// Split text into sentences.
    /// - Parameter text: Input text
    /// - Returns: Array of sentence strings
    public static func sentences(from text: String) -> [String] {
        let cleaned = stripHTML(text)
        // Split on sentence-ending punctuation followed by whitespace or end of string
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

        // Add remaining text if any
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            results.append(trimmed)
        }

        return results
    }

    /// Strip HTML tags from text.
    /// - Parameter text: HTML string
    /// - Returns: Plain text with tags removed
    public static func stripHTML(_ text: String) -> String {
        var result = text
        // Remove HTML tags
        while let openRange = result.range(of: "<"),
              let closeRange = result.range(of: ">", range: openRange.upperBound..<result.endIndex) {
            result.removeSubrange(openRange.lowerBound...closeRange.lowerBound)
        }
        // Decode common HTML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result
    }
}
