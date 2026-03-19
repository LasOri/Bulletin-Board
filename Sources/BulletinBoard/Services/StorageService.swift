import Foundation
import LINKER
#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

public actor StorageService {

    public enum StorageError: Error, Equatable {
        case encodingFailed
        case decodingFailed
        case notFound
        case saveFailed(String)
        case securityInitializationFailed(String)
    }

    private enum StorageBackend {
        case webAuthn(TransparentSecureStorage)
        case indexedDB(IndexedDB)
        case inMemory
    }

    private var backend: StorageBackend?
    private var inMemoryStore: [String: Data] = [:]

    public init(useInMemoryStorage: Bool = false) {
        if useInMemoryStorage {
            self.backend = .inMemory
        }
    }

    private func ensureBackend() async -> StorageBackend {
        if let backend = self.backend {
            return backend
        }

        #if canImport(JavaScriptKit) && arch(wasm32)
        do {
            let storage = try await SecureApp.createSecureStorageWithWebAuthn(
                name: "bulletin_board_secure"
            )
            let b = StorageBackend.webAuthn(storage)
            self.backend = b
            await Logger.shared.info(AppLogFeature.storage, "Storage initialized with WebAuthn")
            return b
        } catch {
            await Logger.shared.warn(AppLogFeature.storage, "WebAuthn unavailable, falling back to IndexedDB: \(error)")
        }

        do {
            let db = try await Self.openWithStore(name: "bulletin_board", storeName: "bb_data")
            let b = StorageBackend.indexedDB(db)
            self.backend = b
            await Logger.shared.info(AppLogFeature.storage, "Storage initialized with plain IndexedDB")
            return b
        } catch {
            await Logger.shared.warn(AppLogFeature.storage, "IndexedDB unavailable, falling back to in-memory: \(error)")
        }
        #endif

        let b = StorageBackend.inMemory
        self.backend = b
        return b
    }

    public func save<T: Codable>(_ value: T, forKey key: String) async throws {
        let backend = await ensureBackend()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else {
            throw StorageError.encodingFailed
        }

        switch backend {
        case .inMemory:
            inMemoryStore[key] = data

        case .webAuthn(let storage):
            let store = storage.store("secure_storage")
            try await store.put(data, key: key)

        case .indexedDB(let db):
            let store = db.store("bb_data")
            try await store.put(data, key: key)
        }
    }

    public func load<T: Codable>(forKey key: String) async throws -> T {
        let backend = await ensureBackend()

        let data: Data

        switch backend {
        case .inMemory:
            guard let storedData = inMemoryStore[key] else {
                throw StorageError.notFound
            }
            data = storedData

        case .webAuthn(let storage):
            let store = storage.store("secure_storage")
            guard let storedData = try await store.get(key, as: Data.self) else {
                throw StorageError.notFound
            }
            data = storedData

        case .indexedDB(let db):
            let store = db.store("bb_data")
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
        let backend = await ensureBackend()

        switch backend {
        case .inMemory:
            inMemoryStore.removeValue(forKey: key)
        case .webAuthn(let storage):
            let store = storage.store("secure_storage")
            try await store.delete(key)
        case .indexedDB(let db):
            let store = db.store("bb_data")
            try await store.delete(key)
        }
    }

    public func exists(forKey key: String) async -> Bool {
        let backend = await ensureBackend()

        switch backend {
        case .inMemory:
            return inMemoryStore[key] != nil
        case .webAuthn(let storage):
            do {
                let store = storage.store("secure_storage")
                let data = try await store.get(key, as: Data.self)
                return data != nil
            } catch {
                return false
            }
        case .indexedDB(let db):
            do {
                let store = db.store("bb_data")
                let data: Data? = try await store.get(key, as: Data.self)
                return data != nil
            } catch {
                return false
            }
        }
    }

    public func clearAll() async throws {
        let backend = await ensureBackend()

        switch backend {
        case .inMemory:
            inMemoryStore.removeAll()
        case .webAuthn(let storage):
            let store = storage.store("secure_storage")
            try await store.clear()
        case .indexedDB(let db):
            let store = db.store("bb_data")
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

    #if canImport(JavaScriptKit) && arch(wasm32)
    private static func openWithStore(name: String, storeName: String) async throws -> IndexedDB {
        guard let indexedDBObj = SafeJSGlobal.global?.indexedDB.object else {
            throw StorageError.saveFailed("IndexedDB not available")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let request = indexedDBObj.open!(name, 1).object!

            let onUpgrade = JSClosure { args in
                guard let event = args.first?.object,
                      let target = event.target.object,
                      let db = target.result.object else {
                    return .undefined
                }

                let storeNames = db.objectStoreNames.object
                let length = Int(storeNames?.length.number ?? 0)
                var hasStore = false
                for i in 0..<length {
                    if storeNames?[i].string == storeName {
                        hasStore = true
                        break
                    }
                }

                if !hasStore {
                    _ = db.createObjectStore!(storeName)
                }

                return .undefined
            }
            request.onupgradeneeded = .object(onUpgrade)

            let onSuccess = JSClosure { args in
                if let event = args.first?.object,
                   let target = event.target.object,
                   let db = target.result.object {
                    _ = db.close!()
                }
                continuation.resume()
                return .undefined
            }
            request.onsuccess = .object(onSuccess)

            let onError = JSClosure { args in
                let msg: String
                if let event = args.first?.object,
                   let target = event.target.object,
                   let error = target.error.object,
                   let message = error.message.string {
                    msg = message
                } else {
                    msg = "Unknown error"
                }
                continuation.resume(throwing: StorageError.saveFailed(msg))
                return .undefined
            }
            request.onerror = .object(onError)
        }

        return try await IndexedDB.open(name: name, version: 1)
    }
    #endif
}

