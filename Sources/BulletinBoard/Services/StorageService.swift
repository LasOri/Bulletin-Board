import Foundation
import LINKER

public actor StorageService {

    public enum StorageError: Error, Equatable {
        case encodingFailed
        case decodingFailed
        case notFound
        case saveFailed(String)
        case securityInitializationFailed(String)
    }

    private var secureStorage: TransparentSecureStorage?
    private var inMemoryStore: [String: Data] = [:]
    private let useInMemoryStorage: Bool

    public init(useInMemoryStorage: Bool = true) {
        self.useInMemoryStorage = useInMemoryStorage
    }

    private func getSecureStorage() async throws -> TransparentSecureStorage {
        if let storage = secureStorage {
            return storage
        }

        #if canImport(JavaScriptKit) && arch(wasm32)
        do {
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

    public func save<T: Codable>(_ value: T, forKey key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(value) else {
            throw StorageError.encodingFailed
        }

        if useInMemoryStorage {
            inMemoryStore[key] = data
        } else {
            let storage = try await getSecureStorage()
            let store = storage.store("secure_storage")
            try await store.put(data, key: key)
        }
    }

    public func load<T: Codable>(forKey key: String) async throws -> T {
        let data: Data

        if useInMemoryStorage {
            guard let storedData = inMemoryStore[key] else {
                throw StorageError.notFound
            }
            data = storedData
        } else {
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

    public func delete(forKey key: String) async throws {
        if useInMemoryStorage {
            inMemoryStore.removeValue(forKey: key)
        } else {
            let storage = try await getSecureStorage()
            let store = storage.store("secure_storage")
            try await store.delete(key)
        }
    }

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

    public func clearAll() async throws {
        if useInMemoryStorage {
            inMemoryStore.removeAll()
        } else {
            let storage = try await getSecureStorage()
            let store = storage.store("secure_storage")
            try await store.clear()
        }
    }

    public func saveArticles(_ articles: [Article]) async throws {
        try await save(articles, forKey: "articles")
    }

    public func loadArticles() async throws -> [Article] {
        try await load(forKey: "articles")
    }

    public func saveFeeds(_ feeds: [Feed]) async throws {
        try await save(feeds, forKey: "feeds")
    }

    public func loadFeeds() async throws -> [Feed] {
        try await load(forKey: "feeds")
    }
}

