import Foundation

/// Service for persisting articles and feeds using storage.
///
/// Provides a simple key-value storage interface with Codable support.
/// In production, this would use IndexedDB (via LINKER's IndexedDB wrapper),
/// but for testing, it uses in-memory storage.
public actor StorageService {

    // MARK: - Error Types

    public enum StorageError: Error, Equatable {
        case encodingFailed
        case decodingFailed
        case notFound
        case saveFailed(String)
    }

    // MARK: - Properties

    private var inMemoryStore: [String: Data] = [:]
    private let useInMemoryStorage: Bool

    // MARK: - Initialization

    public init(useInMemoryStorage: Bool = true) {
        self.useInMemoryStorage = useInMemoryStorage
    }

    // MARK: - Public Methods

    /// Saves a Codable value to storage.
    /// - Parameters:
    ///   - value: The value to save
    ///   - key: The storage key
    public func save<T: Codable>(_ value: T, forKey key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(value) else {
            throw StorageError.encodingFailed
        }

        if useInMemoryStorage {
            inMemoryStore[key] = data
        } else {
            // TODO: Use LINKER's IndexedDB when in WASM environment
            throw StorageError.saveFailed("IndexedDB not yet implemented")
        }
    }

    /// Loads a Codable value from storage.
    /// - Parameter key: The storage key
    /// - Returns: The decoded value
    public func load<T: Codable>(forKey key: String) async throws -> T {
        let data: Data

        if useInMemoryStorage {
            guard let storedData = inMemoryStore[key] else {
                throw StorageError.notFound
            }
            data = storedData
        } else {
            // TODO: Use LINKER's IndexedDB when in WASM environment
            throw StorageError.notFound
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let value = try? decoder.decode(T.self, from: data) else {
            throw StorageError.decodingFailed
        }

        return value
    }

    /// Deletes a value from storage.
    /// - Parameter key: The storage key
    public func delete(forKey key: String) async {
        if useInMemoryStorage {
            inMemoryStore.removeValue(forKey: key)
        } else {
            // TODO: Use LINKER's IndexedDB when in WASM environment
        }
    }

    /// Checks if a key exists in storage.
    /// - Parameter key: The storage key
    /// - Returns: True if the key exists
    public func exists(forKey key: String) async -> Bool {
        if useInMemoryStorage {
            return inMemoryStore[key] != nil
        } else {
            // TODO: Use LINKER's IndexedDB when in WASM environment
            return false
        }
    }

    /// Clears all storage.
    public func clearAll() async {
        if useInMemoryStorage {
            inMemoryStore.removeAll()
        } else {
            // TODO: Use LINKER's IndexedDB when in WASM environment
        }
    }

    // MARK: - Convenience Methods

    /// Saves an array of articles.
    public func saveArticles(_ articles: [Article]) async throws {
        try await save(articles, forKey: "articles")
    }

    /// Loads all saved articles.
    public func loadArticles() async throws -> [Article] {
        try await load(forKey: "articles")
    }

    /// Saves an array of feeds.
    public func saveFeeds(_ feeds: [Feed]) async throws {
        try await save(feeds, forKey: "feeds")
    }

    /// Loads all saved feeds.
    public func loadFeeds() async throws -> [Feed] {
        try await load(forKey: "feeds")
    }
}
