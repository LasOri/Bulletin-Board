import LINKER

public enum KeywordExtractor {

    public struct ScoredKeyword: Equatable, Sendable {
        public let phrase: String
        public let score: Double

        public init(phrase: String, score: Double) {
            self.phrase = phrase
            self.score = score
        }
    }

    public static func extract(from text: String, maxKeywords: Int = 10) -> [ScoredKeyword] {
        let cleanText = TextProcessor.stripHTML(text)
        let sentences = TextProcessor.sentences(from: cleanText)

        guard !sentences.isEmpty else { return [] }

        var candidates: [[String]] = []
        for sentence in sentences {
            let phrases = splitByStopWords(sentence)
            candidates.append(contentsOf: phrases)
        }

        guard !candidates.isEmpty else { return [] }

        var wordFrequency: [String: Int] = [:]
        var wordDegree: [String: Int] = [:]

        for phrase in candidates {
            let degree = phrase.count - 1
            for word in phrase {
                wordFrequency[word, default: 0] += 1
                wordDegree[word, default: 0] += degree
            }
        }

        var wordScore: [String: Double] = [:]
        for (word, freq) in wordFrequency {
            let deg = wordDegree[word, default: 0]
            wordScore[word] = Double(deg + freq) / Double(freq)
        }

        var phraseScores: [String: Double] = [:]
        for phrase in candidates {
            let phraseText = phrase.joined(separator: " ")
            if phraseText.isEmpty { continue }
            let score = phrase.reduce(0.0) { $0 + (wordScore[$1] ?? 0.0) }
            if let existing = phraseScores[phraseText] {
                phraseScores[phraseText] = max(existing, score)
            } else {
                phraseScores[phraseText] = score
            }
        }

        let sorted = phraseScores
            .map { ScoredKeyword(phrase: $0.key, score: $0.value) }
            .sorted { $0.score > $1.score }

        return Array(sorted.prefix(maxKeywords))
    }

    private static func splitByStopWords(_ sentence: String) -> [[String]] {
        let words = sentence
            .lowercased()
            .splitByWhitespace()
            .map { $0.trimmingPunctuation() }
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

