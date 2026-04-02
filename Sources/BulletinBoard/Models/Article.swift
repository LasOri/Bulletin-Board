import LINKER

public struct ArticleColor: Equatable, Sendable {
    public let r: Float
    public let g: Float
    public let b: Float

    public init(r: Float, g: Float, b: Float) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public struct Article: Equatable, Identifiable, Sendable {
    public let id: String

    public let title: String

    public let description: String?

    public let content: String?

    public let url: String

    public let publishedAt: Double?

    public let author: String?

    public let feedId: String

    public let categories: [String]

    public let enclosure: ArticleEnclosure?

    public var isRead: Bool

    public var isFavorite: Bool

    public var isArchived: Bool

    public var nlpSummary: String?

    public var keywords: [String]

    public var autoCategory: ArticleCategory?

    public var sentimentScore: Double?

    public var clusterId: Int?

    public var dominantColor: ArticleColor?

    public let addedAt: Double

    public var updatedAt: Double

    public init(
        id: String,
        title: String,
        description: String? = nil,
        content: String? = nil,
        url: String,
        publishedAt: Double? = nil,
        author: String? = nil,
        feedId: String,
        categories: [String] = [],
        enclosure: ArticleEnclosure? = nil,
        isRead: Bool = false,
        isFavorite: Bool = false,
        isArchived: Bool = false,
        nlpSummary: String? = nil,
        keywords: [String] = [],
        autoCategory: ArticleCategory? = nil,
        sentimentScore: Double? = nil,
        clusterId: Int? = nil,
        dominantColor: ArticleColor? = nil,
        addedAt: Double = currentTimestamp(),
        updatedAt: Double = currentTimestamp()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.content = content
        self.url = url
        self.publishedAt = publishedAt
        self.author = author
        self.feedId = feedId
        self.categories = categories
        self.enclosure = enclosure
        self.isRead = isRead
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.nlpSummary = nlpSummary
        self.keywords = keywords
        self.autoCategory = autoCategory
        self.sentimentScore = sentimentScore
        self.clusterId = clusterId
        self.dominantColor = dominantColor
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }

    public static func from(rssItem: RSSItem, feedId: String) -> Article {
        let enc: ArticleEnclosure?
        if let rssEnc = rssItem.enclosure {
            enc = ArticleEnclosure(url: rssEnc.url, type: rssEnc.type, length: rssEnc.length)
        } else {
            enc = nil
        }
        return Article(
            id: rssItem.id,
            title: rssItem.title,
            description: rssItem.description,
            content: rssItem.content,
            url: rssItem.link,
            publishedAt: rssItem.pubDate,
            author: rssItem.author,
            feedId: feedId,
            categories: rssItem.categories,
            enclosure: enc
        )
    }
}

public struct ArticleEnclosure: Equatable, Sendable {
    public let url: String
    public let type: String
    public let length: Int?

    public init(url: String, type: String, length: Int? = nil) {
        self.url = url
        self.type = type
        self.length = length
    }
}

public enum ArticleCategory: String, CaseIterable, Sendable {
    case technology = "Technology"
    case science = "Science"
    case politics = "Politics"
    case business = "Business"
    case health = "Health"
    case entertainment = "Entertainment"
    case sports = "Sports"
    case world = "World"
    case opinion = "Opinion"
    case lifestyle = "Lifestyle"
    case other = "Other"

    public var color: String {
        switch self {
        case .technology: return "#3b82f6"
        case .science: return "#10b981"
        case .politics: return "#ef4444"
        case .business: return "#f59e0b"
        case .health: return "#ec4899"
        case .entertainment: return "#8b5cf6"
        case .sports: return "#06b6d4"
        case .world: return "#6366f1"
        case .opinion: return "#f97316"
        case .lifestyle: return "#14b8a6"
        case .other: return "#6b7280"
        }
    }
}

extension Article {
    public var heroImageURL: String? {
        if let enc = enclosure, enc.type.hasPrefix("image/") {
            return enc.url
        }
        return Self.extractFirstImageURL(from: content)
            ?? Self.extractFirstImageURL(from: description)
    }

    private static func extractFirstImageURL(from html: String?) -> String? {
        guard let html = html else { return nil }
        var searchStart = html.startIndex
        while let imgRange = html.findRangeIgnoringCase(of: "<img ", from: searchStart) {
            let tagEnd = html.findRange(of: ">", from: imgRange.upperBound)?.upperBound ?? html.endIndex
            let tagContent = String(html[imgRange.lowerBound..<tagEnd])
            if let url = extractSrcAttribute(from: tagContent), url.hasPrefix("http") {
                return url
            }
            searchStart = tagEnd
        }
        return nil
    }

    private static func extractSrcAttribute(from tag: String) -> String? {
        for pattern in ["src=\"", "src='"] {
            guard let start = tag.findRangeIgnoringCase(of: pattern) else { continue }
            let valueStart = start.upperBound
            let quote = String(pattern.last!)
            guard let end = tag.findRange(of: quote, from: valueStart) else { continue }
            return String(tag[valueStart..<end.lowerBound])
        }
        return nil
    }

    public var displayContent: String {
        nlpSummary ?? description ?? content ?? ""
    }

    public var textForNLP: String {
        var parts: [String] = [title]
        if let d = description { parts.append(d) }
        if let c = content { parts.append(c) }
        let raw = parts.joined(separator: " ")
        if raw.count > 500 {
            return String(raw.prefix(500))
        }
        return raw
    }

    public var isNLPProcessed: Bool {
        nlpSummary != nil && !keywords.isEmpty
    }

    public var sentimentLabel: String? {
        guard let score = sentimentScore else { return nil }
        if score > 0.1 { return "Positive" }
        if score < -0.1 { return "Negative" }
        return "Neutral"
    }

    public mutating func markAsRead() {
        isRead = true
        updatedAt = currentTimestamp()
    }

    public mutating func toggleFavorite() {
        isFavorite.toggle()
        updatedAt = currentTimestamp()
    }

    public mutating func archive() {
        isArchived = true
        updatedAt = currentTimestamp()
    }

    public mutating func updateNLP(
        summary: String?,
        keywords: [String],
        category: ArticleCategory?,
        sentiment: Double?,
        cluster: Int?
    ) {
        self.nlpSummary = summary
        self.keywords = keywords
        self.autoCategory = category
        self.sentimentScore = sentiment
        self.clusterId = cluster
        self.updatedAt = currentTimestamp()
    }

    public mutating func updateDominantColor(_ color: ArticleColor) {
        self.dominantColor = color
        self.updatedAt = currentTimestamp()
    }
}

extension ArticleColor {
    public func toJson() -> Json {
        .object([
            "r": .double(Double(r)),
            "g": .double(Double(g)),
            "b": .double(Double(b))
        ])
    }

    public init?(json: Json) {
        guard let r = json["r"]?.doubleValue,
              let g = json["g"]?.doubleValue,
              let b = json["b"]?.doubleValue else { return nil }
        self.r = Float(r)
        self.g = Float(g)
        self.b = Float(b)
    }
}

extension ArticleEnclosure {
    public func toJson() -> Json {
        var obj: [String: Json] = [
            "url": .string(url),
            "type": .string(type)
        ]
        if let length = length {
            obj["length"] = .double(Double(length))
        }
        return .object(obj)
    }

    public init?(json: Json) {
        guard let url = json["url"]?.stringValue,
              let type = json["type"]?.stringValue else { return nil }
        self.url = url
        self.type = type
        if let lengthDouble = json["length"]?.doubleValue {
            self.length = Int(lengthDouble)
        } else {
            self.length = nil
        }
    }
}

extension ArticleCategory {
    public func toJson() -> Json {
        .string(rawValue)
    }

    public init?(json: Json) {
        guard let raw = json.stringValue else { return nil }
        self.init(rawValue: raw)
    }
}

extension Article {
    public func toJson() -> Json {
        var obj: [String: Json] = [
            "id": .string(id),
            "title": .string(title),
            "url": .string(url),
            "feedId": .string(feedId),
            "isRead": .bool(isRead),
            "isFavorite": .bool(isFavorite),
            "isArchived": .bool(isArchived),
            "keywords": .array(keywords.map { .string($0) }),
            "categories": .array(categories.map { .string($0) }),
            "addedAt": .double(addedAt),
            "updatedAt": .double(updatedAt)
        ]
        if let v = description { obj["description"] = .string(v) }
        if let v = content { obj["content"] = .string(v) }
        if let v = publishedAt { obj["publishedAt"] = .double(v) }
        if let v = author { obj["author"] = .string(v) }
        if let v = enclosure { obj["enclosure"] = v.toJson() }
        if let v = nlpSummary { obj["nlpSummary"] = .string(v) }
        if let v = autoCategory { obj["autoCategory"] = v.toJson() }
        if let v = sentimentScore { obj["sentimentScore"] = .double(v) }
        if let v = clusterId { obj["clusterId"] = .double(Double(v)) }
        if let v = dominantColor { obj["dominantColor"] = v.toJson() }
        return .object(obj)
    }

    public init?(json: Json) {
        guard let id = json["id"]?.stringValue,
              let title = json["title"]?.stringValue,
              let url = json["url"]?.stringValue,
              let feedId = json["feedId"]?.stringValue else { return nil }
        self.id = id
        self.title = title
        self.description = json["description"]?.stringValue
        self.content = json["content"]?.stringValue
        self.url = url
        self.publishedAt = json["publishedAt"]?.doubleValue
        self.author = json["author"]?.stringValue
        self.feedId = feedId
        self.categories = Article.extractStrings(from: json["categories"]?.arrayValue)
        if let encJson = json["enclosure"] {
            self.enclosure = ArticleEnclosure(json: encJson)
        } else {
            self.enclosure = nil
        }
        self.isRead = json["isRead"]?.boolValue ?? false
        self.isFavorite = json["isFavorite"]?.boolValue ?? false
        self.isArchived = json["isArchived"]?.boolValue ?? false
        self.nlpSummary = json["nlpSummary"]?.stringValue
        self.keywords = Article.extractStrings(from: json["keywords"]?.arrayValue)
        if let catJson = json["autoCategory"] {
            self.autoCategory = ArticleCategory(json: catJson)
        } else {
            self.autoCategory = nil
        }
        self.sentimentScore = json["sentimentScore"]?.doubleValue
        if let clusterDouble = json["clusterId"]?.doubleValue {
            self.clusterId = Int(clusterDouble)
        } else {
            self.clusterId = nil
        }
        if let colorJson = json["dominantColor"] {
            self.dominantColor = ArticleColor(json: colorJson)
        } else {
            self.dominantColor = nil
        }
        self.addedAt = json["addedAt"]?.doubleValue ?? currentTimestamp()
        self.updatedAt = json["updatedAt"]?.doubleValue ?? currentTimestamp()
    }

    private static func extractStrings(from array: [Json]?) -> [String] {
        guard let array = array else { return [] }
        var result: [String] = []
        for item in array {
            if let s = item.stringValue {
                result.append(s)
            }
        }
        return result
    }
}
