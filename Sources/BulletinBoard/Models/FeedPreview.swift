import LINKER

public struct FeedPreview: Sendable {
    public enum State: Sendable {
        case idle
        case discovering
        case success([DiscoveredFeed], sampleArticles: [PreviewArticle])
        case error(String)
    }

    public struct PreviewArticle: Sendable {
        public let title: String
        public let publishedAt: Double?

        public init(title: String, publishedAt: Double?) {
            self.title = title
            self.publishedAt = publishedAt
        }
    }

    public let inputURL: String
    public let state: State

    public init(inputURL: String, state: State) {
        self.inputURL = inputURL
        self.state = state
    }
}
