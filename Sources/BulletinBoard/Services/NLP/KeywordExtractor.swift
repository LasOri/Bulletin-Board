import Foundation

/// RAKE (Rapid Automatic Keyword Extraction) implementation.
///
/// Extracts keywords by:
/// 1. Splitting text into sentences
/// 2. Splitting sentences by stop words to find candidate phrases
/// 3. Scoring phrases by word degree/frequency ratio
/// 4. Returning top-N ranked keywords
public enum KeywordExtractor {

    /// A keyword phrase with its RAKE score.
    public struct ScoredKeyword: Equatable, Sendable {
        public let phrase: String
        public let score: Double

        public init(phrase: String, score: Double) {
            self.phrase = phrase
            self.score = score
        }
    }

    /// Extract keywords from text using the RAKE algorithm.
    /// - Parameters:
    ///   - text: Input text
    ///   - maxKeywords: Maximum number of keywords to return (default: 10)
    /// - Returns: Array of scored keywords sorted by score descending
    public static func extract(from text: String, maxKeywords: Int = 10) -> [ScoredKeyword] {
        let cleanText = TextProcessor.stripHTML(text)
        let sentences = TextProcessor.sentences(from: cleanText)

        guard !sentences.isEmpty else { return [] }

        // Build candidate phrases by splitting sentences on stop words
        var candidates: [[String]] = []
        for sentence in sentences {
            let phrases = splitByStopWords(sentence)
            candidates.append(contentsOf: phrases)
        }

        guard !candidates.isEmpty else { return [] }

        // Calculate word frequency and degree
        var wordFrequency: [String: Int] = [:]
        var wordDegree: [String: Int] = [:]

        for phrase in candidates {
            let degree = phrase.count - 1
            for word in phrase {
                wordFrequency[word, default: 0] += 1
                wordDegree[word, default: 0] += degree
            }
        }

        // Word score = degree(w) / frequency(w)
        var wordScore: [String: Double] = [:]
        for (word, freq) in wordFrequency {
            let deg = wordDegree[word, default: 0]
            wordScore[word] = Double(deg + freq) / Double(freq)
        }

        // Phrase score = sum of word scores
        var phraseScores: [String: Double] = [:]
        for phrase in candidates {
            let phraseText = phrase.joined(separator: " ")
            if phraseText.isEmpty { continue }
            let score = phrase.reduce(0.0) { $0 + (wordScore[$1] ?? 0.0) }
            // Keep the highest score if phrase appears multiple times
            if let existing = phraseScores[phraseText] {
                phraseScores[phraseText] = max(existing, score)
            } else {
                phraseScores[phraseText] = score
            }
        }

        // Sort by score and return top-N
        let sorted = phraseScores
            .map { ScoredKeyword(phrase: $0.key, score: $0.value) }
            .sorted { $0.score > $1.score }

        return Array(sorted.prefix(maxKeywords))
    }

    /// Split a sentence into candidate phrases by removing stop words.
    /// Returns arrays of consecutive non-stop words.
    private static func splitByStopWords(_ sentence: String) -> [[String]] {
        let words = sentence
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        var phrases: [[String]] = []
        var current: [String] = []

        for word in words {
            if TextProcessor.stopWords.contains(word) || word.count < 3 {
                if !current.isEmpty {
                    phrases.append(current)
                    current = []
                }
            } else {
                current.append(word)
            }
        }

        if !current.isEmpty {
            phrases.append(current)
        }

        return phrases
    }
}
