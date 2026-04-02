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
    private var inMemoryStore: [String: String] = [:]

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

    public func saveArticles(_ articles: [Article]) async throws {
        let jsonArray = Json.array(articles.map { $0.toJson() })
        let jsonString = jsonArray.toJsonString(pretty: false)
        try await saveRaw(jsonString, forKey: "articles")
    }

    public func loadArticles() async throws -> [Article] {
        let jsonString = try await loadRaw(forKey: "articles")
        let parsed = Json.parse(jsonString)
        guard let array = parsed.arrayValue else {
            throw StorageError.decodingFailed
        }
        var result: [Article] = []
        for item in array {
            if let article = Article(json: item) {
                result.append(article)
            }
        }
        return result
    }

    public func saveFeeds(_ feeds: [Feed]) async throws {
        let jsonArray = Json.array(feeds.map { $0.toJson() })
        let jsonString = jsonArray.toJsonString(pretty: false)
        try await saveRaw(jsonString, forKey: "feeds")
    }

    public func loadFeeds() async throws -> [Feed] {
        let jsonString = try await loadRaw(forKey: "feeds")
        let parsed = Json.parse(jsonString)
        guard let array = parsed.arrayValue else {
            throw StorageError.decodingFailed
        }
        var result: [Feed] = []
        for item in array {
            if let feed = Feed(json: item) {
                result.append(feed)
            }
        }
        return result
    }

    public func save(_ value: String, forKey key: String) async throws {
        try await saveRaw(value, forKey: key)
    }

    public func load(forKey key: String) async throws -> String {
        try await loadRaw(forKey: key)
    }

    private func saveRaw(_ value: String, forKey key: String) async throws {
        let backend = await ensureBackend()

        switch backend {
        case .inMemory:
            inMemoryStore[key] = value

        case .webAuthn(let storage):
            let store = storage.store("secure_storage")
            try await store.put(.string(value), key: key)

        case .indexedDB(let db):
            let store = db.store("bb_data")
            try await store.putRaw(value, key: key)
        }
    }

    private func loadRaw(forKey key: String) async throws -> String {
        let backend = await ensureBackend()

        switch backend {
        case .inMemory:
            guard let value = inMemoryStore[key] else {
                throw StorageError.notFound
            }
            return value

        case .webAuthn(let storage):
            let store = storage.store("secure_storage")
            guard let json = try await store.get(key),
                  let value = json.stringValue else {
                throw StorageError.notFound
            }
            return value

        case .indexedDB(let db):
            let store = db.store("bb_data")
            guard let jsonString = try await store.getRaw(key) else {
                throw StorageError.notFound
            }
            return jsonString
        }
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
                let json = try await store.get(key)
                return json != nil
            } catch {
                return false
            }
        case .indexedDB(let db):
            do {
                let store = db.store("bb_data")
                let jsonString = try await store.getRaw(key)
                return jsonString != nil
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

    #if canImport(JavaScriptKit) && arch(wasm32)
    private static func openWithStore(name: String, storeName: String) async throws -> IndexedDB {
        guard let indexedDBObj = SafeJSGlobal.global?.indexedDB.object else {
            throw StorageError.saveFailed("IndexedDB not available")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let request = (try? indexedDBObj.throwing.open?(name, 1))?.object else {
                continuation.resume(throwing: StorageError.saveFailed("IndexedDB open failed"))
                return
            }

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
                    _ = try? db.throwing.createObjectStore?(storeName)
                }

                return .undefined
            }
            request.onupgradeneeded = .object(onUpgrade)

            let onSuccess = JSClosure { args in
                if let event = args.first?.object,
                   let target = event.target.object,
                   let db = target.result.object {
                    _ = try? db.throwing.close?()
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
