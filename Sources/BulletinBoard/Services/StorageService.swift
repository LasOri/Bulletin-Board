import Foundation
import LINKER

/// Service for persisting articles and feeds using secure encrypted storage.
///
/// Uses LINKER's TransparentSecureStorage with WebAuthn hardware-backed encryption:
/// - AES-256-GCM encryption
/// - Hardware security keys (YubiKey, TouchID, Windows Hello)
/// - Automatic key derivation
/// - Transparent encryption/decryption
///
/// Falls back to in-memory storage for testing environments.
public actor StorageService {

    // MARK: - Error Types

    public enum StorageError: Error, Equatable {
        case encodingFailed
        case decodingFailed
        case notFound
        case saveFailed(String)
        case securityInitializationFailed(String)
    }

    // MARK: - Properties

    private var secureStorage: TransparentSecureStorage?
    private var inMemoryStore: [String: Data] = [:]
    private let useInMemoryStorage: Bool

    // MARK: - Initialization

    /// Creates a new StorageService.
    /// - Parameter useInMemoryStorage: If true, uses in-memory storage (for testing)
    ///                                 If false, uses TransparentSecureStorage with WebAuthn
    public init(useInMemoryStorage: Bool = true) {
        self.useInMemoryStorage = useInMemoryStorage
    }

    // MARK: - Secure Storage Access

    /// Gets or initializes the secure storage instance.
    /// Uses WebAuthn hardware-backed encryption for maximum security.
    private func getSecureStorage() async throws -> TransparentSecureStorage {
        if let storage = secureStorage {
            return storage
        }

        #if canImport(JavaScriptKit) && arch(wasm32)
        do {
            // Initialize WebAuthn-backed secure storage
            // This will prompt user for TouchID/YubiKey on first use
            let storage = try await SecureApp.createSecureStorageWithWebAuthn(
                name: "bulletin_board_secure"
            )
            self.secureStorage = storage
            print("✅ Secure storage initialized with WebAuthn hardware-backed encryption")
            return storage
        } catch {
            throw StorageError.securityInitializationFailed(
                "Failed to initialize WebAuthn secure storage: \(error)"
            )
        }
        #else
        throw StorageError.securityInitializationFailed(
            "Secure storage only available in WASM environment"
        )
        #endif
    }

    // MARK: - Public Methods

    /// Saves a Codable value to storage with encryption.
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
            // Testing: in-memory storage
            inMemoryStore[key] = data
        } else {
            // Production: encrypted secure storage
            let storage = try await getSecureStorage()
            let store = storage.store("secure_storage")
            try await store.put(data, key: key)
        }
    }

    /// Loads a Codable value from storage with automatic decryption.
    /// - Parameter key: The storage key
    /// - Returns: The decoded value
    public func load<T: Codable>(forKey key: String) async throws -> T {
        let data: Data

        if useInMemoryStorage {
            // Testing: in-memory storage
            guard let storedData = inMemoryStore[key] else {
                throw StorageError.notFound
            }
            data = storedData
        } else {
            // Production: encrypted secure storage
            let storage = try await getSecureStorage()
            let store = storage.store("secure_storage")
            guard let storedData = try await store.get(key, as: Data.self) else {
                throw StorageError.notFound
            }
            data = storedData
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
    public func delete(forKey key: String) async throws {
        if useInMemoryStorage {
            inMemoryStore.removeValue(forKey: key)
        } else {
            let storage = try await getSecureStorage()
            let store = storage.store("secure_storage")
            try await store.delete(key)
        }
    }

    /// Checks if a key exists in storage.
    /// - Parameter key: The storage key
    /// - Returns: True if the key exists
    public func exists(forKey key: String) async -> Bool {
        if useInMemoryStorage {
            return inMemoryStore[key] != nil
        } else {
            do {
                let storage = try await getSecureStorage()
                let store = storage.store("secure_storage")
                let data = try await store.get(key, as: Data.self)
                return data != nil
            } catch {
                return false
            }
        }
    }

    /// Clears all storage.
    public func clearAll() async throws {
        if useInMemoryStorage {
            inMemoryStore.removeAll()
        } else {
            let storage = try await getSecureStorage()
            let store = storage.store("secure_storage")
            try await store.clear()
        }
    }

    // MARK: - Convenience Methods

    /// Saves an array of articles with encryption.
    public func saveArticles(_ articles: [Article]) async throws {
        try await save(articles, forKey: "articles")
    }

    /// Loads all saved articles with automatic decryption.
    public func loadArticles() async throws -> [Article] {
        try await load(forKey: "articles")
    }

    /// Saves an array of feeds with encryption.
    public func saveFeeds(_ feeds: [Feed]) async throws {
        try await save(feeds, forKey: "feeds")
    }

    /// Loads all saved feeds with automatic decryption.
    public func loadFeeds() async throws -> [Feed] {
        try await load(forKey: "feeds")
    }
}
