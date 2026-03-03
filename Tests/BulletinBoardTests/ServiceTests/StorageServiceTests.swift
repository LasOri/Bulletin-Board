import XCTest
@testable import BulletinBoard

final class StorageServiceTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTestStorageService() -> StorageService {
        StorageService(useInMemoryStorage: true)
    }

    private func makeTestArticle(id: String = "test-1") -> Article {
        Article(
            id: id,
            title: "Test Article",
            url: "https://example.com/article",
            feedId: "feed-1"
        )
    }

    private func makeTestFeed(id: String = "feed-1") -> Feed {
        Feed(
            id: id,
            title: "Test Feed",
            description: "Test feed description",
            url: "https://example.com/feed.xml"
        )
    }

    // MARK: - Save and Load Tests

    func testSaveAndLoadString() async throws {
        let service = makeTestStorageService()
        let testValue = "Hello, World!"

        try await service.save(testValue, forKey: "test-string")
        let loaded: String = try await service.load(forKey: "test-string")

        XCTAssertEqual(loaded, testValue)
    }

    func testSaveAndLoadArticle() async throws {
        let service = makeTestStorageService()
        let article = makeTestArticle()

        try await service.save(article, forKey: "test-article")
        let loaded: Article = try await service.load(forKey: "test-article")

        XCTAssertEqual(loaded.id, article.id)
        XCTAssertEqual(loaded.title, article.title)
        XCTAssertEqual(loaded.url, article.url)
        XCTAssertEqual(loaded.feedId, article.feedId)
    }

    func testSaveAndLoadMultipleArticles() async throws {
        let service = makeTestStorageService()
        let articles = [
            makeTestArticle(id: "1"),
            makeTestArticle(id: "2"),
            makeTestArticle(id: "3")
        ]

        try await service.saveArticles(articles)
        let loaded = try await service.loadArticles()

        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].id, "1")
        XCTAssertEqual(loaded[1].id, "2")
        XCTAssertEqual(loaded[2].id, "3")
    }

    func testSaveAndLoadFeeds() async throws {
        let service = makeTestStorageService()
        let feeds = [
            makeTestFeed(id: "feed-1"),
            makeTestFeed(id: "feed-2")
        ]

        try await service.saveFeeds(feeds)
        let loaded = try await service.loadFeeds()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, "feed-1")
        XCTAssertEqual(loaded[1].id, "feed-2")
    }

    // MARK: - Error Tests

    func testLoadNonExistentKey() async {
        let service = makeTestStorageService()

        do {
            let _: String = try await service.load(forKey: "nonexistent")
            XCTFail("Should throw notFound error")
        } catch StorageService.StorageError.notFound {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Delete Tests

    func testDelete() async throws {
        let service = makeTestStorageService()
        let testValue = "Test"

        try await service.save(testValue, forKey: "test-delete")
        let existsBefore = await service.exists(forKey: "test-delete")
        XCTAssertTrue(existsBefore)

        try await service.delete(forKey: "test-delete")
        let existsAfter = await service.exists(forKey: "test-delete")
        XCTAssertFalse(existsAfter)
    }

    // MARK: - Exists Tests

    func testExists() async throws {
        let service = makeTestStorageService()

        let existsBefore = await service.exists(forKey: "test-exists")
        XCTAssertFalse(existsBefore)

        try await service.save("value", forKey: "test-exists")
        let existsAfter = await service.exists(forKey: "test-exists")
        XCTAssertTrue(existsAfter)
    }

    // MARK: - Clear Tests

    func testClearAll() async throws {
        let service = makeTestStorageService()

        try await service.save("value1", forKey: "key1")
        try await service.save("value2", forKey: "key2")
        try await service.save("value3", forKey: "key3")

        let exists1 = await service.exists(forKey: "key1")
        let exists2 = await service.exists(forKey: "key2")
        let exists3 = await service.exists(forKey: "key3")
        XCTAssertTrue(exists1)
        XCTAssertTrue(exists2)
        XCTAssertTrue(exists3)

        try await service.clearAll()

        let notExists1 = await service.exists(forKey: "key1")
        let notExists2 = await service.exists(forKey: "key2")
        let notExists3 = await service.exists(forKey: "key3")
        XCTAssertFalse(notExists1)
        XCTAssertFalse(notExists2)
        XCTAssertFalse(notExists3)
    }

    // MARK: - Update Tests

    func testUpdateValue() async throws {
        let service = makeTestStorageService()

        try await service.save("original", forKey: "test-update")
        let original: String = try await service.load(forKey: "test-update")
        XCTAssertEqual(original, "original")

        try await service.save("updated", forKey: "test-update")
        let updated: String = try await service.load(forKey: "test-update")
        XCTAssertEqual(updated, "updated")
    }

    // MARK: - Error Type Tests

    func testStorageErrorEquatable() {
        let error1 = StorageService.StorageError.notFound
        let error2 = StorageService.StorageError.notFound
        XCTAssertEqual(error1, error2)

        let error3 = StorageService.StorageError.saveFailed("test")
        let error4 = StorageService.StorageError.saveFailed("test")
        XCTAssertEqual(error3, error4)

        XCTAssertNotEqual(error1, error3)
    }
}
