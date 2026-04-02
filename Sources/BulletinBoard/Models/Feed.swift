import LINKER

public struct Feed: Equatable, Identifiable, Sendable {
    public let id: String

    public let title: String

    public let description: String

    public let url: String

    public let siteUrl: String?

    public let language: String?

    public var iconUrl: String?

    public var userCategory: String?

    public var updateFrequency: Int

    public var lastFetched: Double?

    public var lastSuccessfulFetch: Double?

    public var lastError: String?

    public var articleCount: Int

    public var unreadCount: Int

    public let subscribedAt: Double

    public var updatedAt: Double

    public var isEnabled: Bool

    public var isFetching: Bool

    public init(
        id: String = uniqueIDString(),
        title: String,
        description: String,
        url: String,
        siteUrl: String? = nil,
        language: String? = nil,
        iconUrl: String? = nil,
        userCategory: String? = nil,
        updateFrequency: Int = 60,
        lastFetched: Double? = nil,
        lastSuccessfulFetch: Double? = nil,
        lastError: String? = nil,
        articleCount: Int = 0,
        unreadCount: Int = 0,
        subscribedAt: Double = currentTimestamp(),
        updatedAt: Double = currentTimestamp(),
        isEnabled: Bool = true,
        isFetching: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.url = url
        self.siteUrl = siteUrl
        self.language = language
        self.iconUrl = iconUrl
        self.userCategory = userCategory
        self.updateFrequency = updateFrequency
        self.lastFetched = lastFetched
        self.lastSuccessfulFetch = lastSuccessfulFetch
        self.lastError = lastError
        self.articleCount = articleCount
        self.unreadCount = unreadCount
        self.subscribedAt = subscribedAt
        self.updatedAt = updatedAt
        self.isEnabled = isEnabled
        self.isFetching = isFetching
    }

    public static func from(rssFeed: RSSFeed, url: String) -> Feed {
        Feed(
            title: rssFeed.title,
            description: rssFeed.description,
            url: url,
            siteUrl: rssFeed.link,
            language: rssFeed.language
        )
    }
}

extension Feed {
    public func needsUpdate() -> Bool {
        guard isEnabled else { return false }

        guard let lastFetch = lastFetched else {
            return true
        }

        let interval = Double(updateFrequency * 60)
        return currentTimestamp() - lastFetch >= interval
    }

    public mutating func startFetching() {
        isFetching = true
        lastFetched = currentTimestamp()
        updatedAt = currentTimestamp()
    }

    public mutating func completeFetch(articleCount: Int) {
        isFetching = false
        lastSuccessfulFetch = currentTimestamp()
        lastError = nil
        self.articleCount = articleCount
        updatedAt = currentTimestamp()
    }

    public mutating func failFetch(error: String) {
        isFetching = false
        lastError = error
        updatedAt = currentTimestamp()
    }

    public mutating func updateUnreadCount(_ count: Int) {
        unreadCount = count
        updatedAt = currentTimestamp()
    }

    public mutating func toggleEnabled() {
        isEnabled.toggle()
        updatedAt = currentTimestamp()
    }
}

extension Feed {
    public func toJson() -> Json {
        var obj: [String: Json] = [
            "id": .string(id),
            "title": .string(title),
            "description": .string(description),
            "url": .string(url),
            "updateFrequency": .double(Double(updateFrequency)),
            "articleCount": .double(Double(articleCount)),
            "unreadCount": .double(Double(unreadCount)),
            "subscribedAt": .double(subscribedAt),
            "updatedAt": .double(updatedAt),
            "isEnabled": .bool(isEnabled),
            "isFetching": .bool(isFetching)
        ]
        if let v = siteUrl { obj["siteUrl"] = .string(v) }
        if let v = language { obj["language"] = .string(v) }
        if let v = iconUrl { obj["iconUrl"] = .string(v) }
        if let v = userCategory { obj["userCategory"] = .string(v) }
        if let v = lastFetched { obj["lastFetched"] = .double(v) }
        if let v = lastSuccessfulFetch { obj["lastSuccessfulFetch"] = .double(v) }
        if let v = lastError { obj["lastError"] = .string(v) }
        return .object(obj)
    }

    public init?(json: Json) {
        guard let id = json["id"]?.stringValue,
              let title = json["title"]?.stringValue,
              let description = json["description"]?.stringValue,
              let url = json["url"]?.stringValue else { return nil }
        self.id = id
        self.title = title
        self.description = description
        self.url = url
        self.siteUrl = json["siteUrl"]?.stringValue
        self.language = json["language"]?.stringValue
        self.iconUrl = json["iconUrl"]?.stringValue
        self.userCategory = json["userCategory"]?.stringValue
        if let freqDouble = json["updateFrequency"]?.doubleValue {
            self.updateFrequency = Int(freqDouble)
        } else {
            self.updateFrequency = 60
        }
        self.lastFetched = json["lastFetched"]?.doubleValue
        self.lastSuccessfulFetch = json["lastSuccessfulFetch"]?.doubleValue
        self.lastError = json["lastError"]?.stringValue
        if let acDouble = json["articleCount"]?.doubleValue {
            self.articleCount = Int(acDouble)
        } else {
            self.articleCount = 0
        }
        if let ucDouble = json["unreadCount"]?.doubleValue {
            self.unreadCount = Int(ucDouble)
        } else {
            self.unreadCount = 0
        }
        self.subscribedAt = json["subscribedAt"]?.doubleValue ?? currentTimestamp()
        self.updatedAt = json["updatedAt"]?.doubleValue ?? currentTimestamp()
        self.isEnabled = json["isEnabled"]?.boolValue ?? true
        self.isFetching = false
    }
}
