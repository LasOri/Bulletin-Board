import Foundation

/// Classifies articles into categories using TF-IDF cosine similarity
/// against pre-defined category seed word profiles.
public struct ArticleCategorizer: Sendable {

    /// Seed word lists per category.
    public static let categorySeeds: [ArticleCategory: [String]] = [
        .technology: [
            "software", "app", "startup", "cloud", "api", "data", "algorithm",
            "computing", "tech", "digital", "internet", "browser", "code",
            "developer", "programming", "silicon", "chip", "processor",
            "cybersecurity", "encryption", "blockchain", "crypto", "robot",
            "automation", "server", "database", "network", "wireless"
        ],
        .science: [
            "research", "study", "experiment", "discovery", "nasa", "physics",
            "biology", "chemistry", "genome", "species", "fossil", "climate",
            "evolution", "molecule", "particle", "quantum", "telescope",
            "laboratory", "hypothesis", "theory", "scientist", "journal",
            "peer", "review", "cells", "protein", "asteroid"
        ],
        .politics: [
            "election", "congress", "senate", "legislation", "vote",
            "democrat", "republican", "president", "governor", "campaign",
            "ballot", "policy", "partisan", "bipartisan", "caucus",
            "filibuster", "amendment", "constitution", "veto", "lobby",
            "politician", "parliament", "regulation", "bill", "law"
        ],
        .business: [
            "market", "stock", "revenue", "company", "investment", "economy",
            "profit", "earnings", "shares", "dividend", "merger", "acquisition",
            "startup", "venture", "capital", "ipo", "valuation", "ceo",
            "corporate", "quarterly", "growth", "recession", "inflation",
            "banking", "finance", "trade", "commerce", "retail"
        ],
        .health: [
            "medical", "disease", "treatment", "hospital", "vaccine",
            "clinical", "patient", "surgery", "diagnosis", "therapy",
            "pharmaceutical", "drug", "trial", "cancer", "virus", "pandemic",
            "symptom", "doctor", "nurse", "healthcare", "wellness",
            "mental", "nutrition", "fitness", "chronic", "infection"
        ],
        .entertainment: [
            "movie", "film", "music", "celebrity", "album", "actor", "series",
            "streaming", "concert", "award", "oscar", "grammy", "emmy",
            "television", "show", "director", "producer", "studio",
            "premiere", "box", "office", "ticket", "soundtrack", "festival",
            "animation", "comedy", "drama"
        ],
        .sports: [
            "game", "team", "player", "match", "championship", "league",
            "score", "coach", "tournament", "athlete", "season", "playoff",
            "draft", "transfer", "stadium", "soccer", "football", "basketball",
            "baseball", "tennis", "olympic", "medal", "racing", "finals",
            "injury", "roster", "referee"
        ],
        .world: [
            "country", "international", "foreign", "diplomatic", "united",
            "nations", "trade", "treaty", "ambassador", "embassy", "summit",
            "conflict", "refugee", "humanitarian", "sanctions", "alliance",
            "border", "migration", "sovereignty", "territory", "global",
            "geopolitical", "peacekeeping", "aid", "coalition"
        ],
        .opinion: [
            "editorial", "commentary", "perspective", "argue", "opinion",
            "debate", "column", "essay", "viewpoint", "analysis", "think",
            "believe", "contend", "critique", "advocate", "disagree",
            "controversial", "provocative", "stance", "argument"
        ],
        .lifestyle: [
            "recipe", "fashion", "travel", "fitness", "wellness", "home",
            "design", "cooking", "restaurant", "vacation", "destination",
            "beauty", "style", "decor", "garden", "hobby", "craft",
            "relationship", "parenting", "meditation", "yoga", "diet"
        ]
    ]

    /// Minimum similarity threshold for classification.
    public let threshold: Double

    public init(threshold: Double = 0.05) {
        self.threshold = threshold
    }

    /// Classify text into the best-matching category.
    /// Returns `.other` if no category exceeds the minimum threshold.
    /// - Parameters:
    ///   - text: Text to classify
    ///   - engine: TF-IDF engine with indexed corpus
    /// - Returns: Best matching category
    public func classify(text: String, using engine: TFIDFEngine) async -> ArticleCategory {
        let textVector = await engine.vectorize(text: text)

        var bestCategory: ArticleCategory = .other
        var bestScore: Double = 0.0

        for (category, seeds) in Self.categorySeeds {
            let seedText = seeds.joined(separator: " ")
            let seedVector = await engine.vectorize(text: seedText)
            let similarity = TFIDFEngine.cosineSimilarity(textVector, seedVector)

            if similarity > bestScore {
                bestScore = similarity
                bestCategory = category
            }
        }

        return bestScore >= threshold ? bestCategory : .other
    }
}
