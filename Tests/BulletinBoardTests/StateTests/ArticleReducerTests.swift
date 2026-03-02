import XCTest
@testable import BulletinBoard

final class ArticleReducerTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTestArticle(
        id: String = "test-1",
        title: String = "Test Article",
        feedId: String = "feed-1",
        isRead: Bool = false,
        isFavorite: Bool = false
    ) -> Article {
        Article(
            id: id,
            title: title,
            url: "https://example.com/\(id)",
            feedId: feedId,
            isRead: isRead,
            isFavorite: isFavorite
        )
    }

    // MARK: - Add Articles Tests

    func test_addArticles_addsToStateAndAllIds() {
        let state = ArticleState()
        let articles = [
            makeTestArticle(id: "1"),
            makeTestArticle(id: "2")
        ]

        let newState = articleReducer(state: state, action: ArticleAction.addArticles(articles))

        XCTAssertEqual(newState.byId.count, 2)
        XCTAssertEqual(newState.allIds.count, 2)
        XCTAssertNotNil(newState.byId["1"])
        XCTAssertNotNil(newState.byId["2"])
        XCTAssertTrue(newState.allIds.contains("1"))
        XCTAssertTrue(newState.allIds.contains("2"))
    }

    func test_addArticles_withDuplicateIds_doesNotAddDuplicates() {
        var state = ArticleState()
        let article1 = makeTestArticle(id: "1")
        state.byId["1"] = article1
        state.allIds = ["1"]

        let articles = [
            makeTestArticle(id: "1", title: "Updated Title"),
            makeTestArticle(id: "2")
        ]

        let newState = articleReducer(state: state, action: ArticleAction.addArticles(articles))

        XCTAssertEqual(newState.byId.count, 2)
        XCTAssertEqual(newState.allIds.count, 2)
        // Original article should remain unchanged
        XCTAssertEqual(newState.byId["1"]?.title, "Test Article")
    }

    // MARK: - Mark As Read Tests

    func test_markAsRead_whenArticleExists_setsIsReadTrue() {
        var state = ArticleState()
        let article = makeTestArticle(id: "1", isRead: false)
        state.byId["1"] = article
        state.allIds = ["1"]

        let newState = articleReducer(state: state, action: ArticleAction.markAsRead(id: "1"))

        XCTAssertTrue(newState.byId["1"]!.isRead)
        XCTAssertNotEqual(newState.byId["1"]!.updatedAt, article.addedAt)
    }

    func test_markAsRead_whenArticleDoesNotExist_doesNotCrash() {
        let state = ArticleState()

        let newState = articleReducer(state: state, action: ArticleAction.markAsRead(id: "nonexistent"))

        XCTAssertEqual(newState, state)
    }

    func test_markAllAsRead_marksAllUnreadArticlesAsRead() {
        var state = ArticleState()
        let article1 = makeTestArticle(id: "1", isRead: false)
        let article2 = makeTestArticle(id: "2", isRead: false)
        let article3 = makeTestArticle(id: "3", isRead: true)
        state.byId = ["1": article1, "2": article2, "3": article3]
        state.allIds = ["1", "2", "3"]

        let newState = articleReducer(state: state, action: ArticleAction.markAllAsRead)

        XCTAssertTrue(newState.byId["1"]!.isRead)
        XCTAssertTrue(newState.byId["2"]!.isRead)
        XCTAssertTrue(newState.byId["3"]!.isRead)
    }

    // MARK: - Toggle Favorite Tests

    func test_toggleFavorite_whenNotFavorite_setsFavoriteTrue() {
        var state = ArticleState()
        let article = makeTestArticle(id: "1", isFavorite: false)
        state.byId["1"] = article
        state.allIds = ["1"]

        let newState = articleReducer(state: state, action: ArticleAction.toggleFavorite(id: "1"))

        XCTAssertTrue(newState.byId["1"]!.isFavorite)
    }

    func test_toggleFavorite_whenFavorite_setsFavoriteFalse() {
        var state = ArticleState()
        let article = makeTestArticle(id: "1", isFavorite: true)
        state.byId["1"] = article
        state.allIds = ["1"]

        let newState = articleReducer(state: state, action: ArticleAction.toggleFavorite(id: "1"))

        XCTAssertFalse(newState.byId["1"]!.isFavorite)
    }

    // MARK: - Archive Tests

    func test_archiveArticle_setsIsArchivedTrue() {
        var state = ArticleState()
        let article = makeTestArticle(id: "1")
        state.byId["1"] = article
        state.allIds = ["1"]

        let newState = articleReducer(state: state, action: ArticleAction.archiveArticle(id: "1"))

        XCTAssertTrue(newState.byId["1"]!.isArchived)
    }

    func test_unarchiveArticle_setsIsArchivedFalse() {
        var state = ArticleState()
        var article = makeTestArticle(id: "1")
        article.isArchived = true
        state.byId["1"] = article
        state.allIds = ["1"]

        let newState = articleReducer(state: state, action: ArticleAction.unarchiveArticle(id: "1"))

        XCTAssertFalse(newState.byId["1"]!.isArchived)
    }

    // MARK: - Remove Article Tests

    func test_removeArticle_removesFromByIdAndAllIds() {
        var state = ArticleState()
        let article = makeTestArticle(id: "1")
        state.byId["1"] = article
        state.allIds = ["1"]

        let newState = articleReducer(state: state, action: ArticleAction.removeArticle(id: "1"))

        XCTAssertNil(newState.byId["1"])
        XCTAssertFalse(newState.allIds.contains("1"))
    }

    func test_removeArticle_whenSelected_clearsSelection() {
        var state = ArticleState()
        let article = makeTestArticle(id: "1")
        state.byId["1"] = article
        state.allIds = ["1"]
        state.selectedId = "1"

        let newState = articleReducer(state: state, action: ArticleAction.removeArticle(id: "1"))

        XCTAssertNil(newState.selectedId)
    }

    func test_removeArticles_removesMultipleArticles() {
        var state = ArticleState()
        state.byId = [
            "1": makeTestArticle(id: "1"),
            "2": makeTestArticle(id: "2"),
            "3": makeTestArticle(id: "3")
        ]
        state.allIds = ["1", "2", "3"]

        let newState = articleReducer(state: state, action: ArticleAction.removeArticles(["1", "3"]))

        XCTAssertNil(newState.byId["1"])
        XCTAssertNotNil(newState.byId["2"])
        XCTAssertNil(newState.byId["3"])
        XCTAssertEqual(newState.allIds, ["2"])
    }

    // MARK: - NLP Update Tests

    func test_updateNLP_updatesArticleNLPFields() {
        var state = ArticleState()
        let article = makeTestArticle(id: "1")
        state.byId["1"] = article
        state.allIds = ["1"]

        let summary = "Test summary"
        let keywords = ["test", "article"]
        let category = ArticleCategory.technology

        let newState = articleReducer(
            state: state,
            action: ArticleAction.updateNLP(
                id: "1",
                summary: summary,
                keywords: keywords,
                category: category,
                sentiment: 0.5,
                cluster: 1
            )
        )

        XCTAssertEqual(newState.byId["1"]!.nlpSummary, summary)
        XCTAssertEqual(newState.byId["1"]!.keywords, keywords)
        XCTAssertEqual(newState.byId["1"]!.autoCategory, category)
        XCTAssertEqual(newState.byId["1"]!.sentimentScore, 0.5)
        XCTAssertEqual(newState.byId["1"]!.clusterId, 1)
    }

    // MARK: - Selection Tests

    func test_selectArticle_setsSelectedId() {
        let state = ArticleState()

        let newState = articleReducer(state: state, action: ArticleAction.selectArticle(id: "1"))

        XCTAssertEqual(newState.selectedId, "1")
    }

    func test_selectArticle_withNil_clearsSelection() {
        var state = ArticleState()
        state.selectedId = "1"

        let newState = articleReducer(state: state, action: ArticleAction.selectArticle(id: nil))

        XCTAssertNil(newState.selectedId)
    }

    // MARK: - Search and Filter Tests

    func test_setSearchQuery_updatesSearchQuery() {
        let state = ArticleState()

        let newState = articleReducer(state: state, action: ArticleAction.setSearchQuery("test"))

        XCTAssertEqual(newState.searchQuery, "test")
    }

    func test_setSortOrder_updatesSortBy() {
        let state = ArticleState()

        let newState = articleReducer(state: state, action: ArticleAction.setSortOrder(.oldest))

        XCTAssertEqual(newState.sortBy, .oldest)
    }

    func test_resetFilters_clearsFiltersAndSearch() {
        var state = ArticleState()
        state.searchQuery = "test"
        state.filters.showOnlyUnread = true
        state.filters.showOnlyFavorites = true

        let newState = articleReducer(state: state, action: ArticleAction.resetFilters)

        XCTAssertEqual(newState.searchQuery, "")
        XCTAssertFalse(newState.filters.showOnlyUnread)
        XCTAssertFalse(newState.filters.showOnlyFavorites)
    }

    // MARK: - Bulk Operations Tests

    func test_markMultipleAsRead_marksSpecifiedArticlesAsRead() {
        var state = ArticleState()
        state.byId = [
            "1": makeTestArticle(id: "1", isRead: false),
            "2": makeTestArticle(id: "2", isRead: false),
            "3": makeTestArticle(id: "3", isRead: false)
        ]
        state.allIds = ["1", "2", "3"]

        let newState = articleReducer(state: state, action: ArticleAction.markMultipleAsRead(["1", "3"]))

        XCTAssertTrue(newState.byId["1"]!.isRead)
        XCTAssertFalse(newState.byId["2"]!.isRead)
        XCTAssertTrue(newState.byId["3"]!.isRead)
    }

    func test_archiveMultiple_archivesSpecifiedArticles() {
        var state = ArticleState()
        state.byId = [
            "1": makeTestArticle(id: "1"),
            "2": makeTestArticle(id: "2"),
            "3": makeTestArticle(id: "3")
        ]
        state.allIds = ["1", "2", "3"]

        let newState = articleReducer(state: state, action: ArticleAction.archiveMultiple(["1", "2"]))

        XCTAssertTrue(newState.byId["1"]!.isArchived)
        XCTAssertTrue(newState.byId["2"]!.isArchived)
        XCTAssertFalse(newState.byId["3"]!.isArchived)
    }

    func test_deleteOlderThan_removesOldArticles() {
        var state = ArticleState()
        let now = Date()
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        let recentDate = Calendar.current.date(byAdding: .day, value: -2, to: now)!

        let oldArticle = Article(
            id: "old",
            title: "Old Article",
            url: "https://example.com/old",
            publishedAt: oldDate,
            feedId: "feed-1"
        )

        let recentArticle = Article(
            id: "recent",
            title: "Recent Article",
            url: "https://example.com/recent",
            publishedAt: recentDate,
            feedId: "feed-1"
        )

        state.byId = ["old": oldArticle, "recent": recentArticle]
        state.allIds = ["old", "recent"]

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -5, to: now)!
        let newState = articleReducer(state: state, action: ArticleAction.deleteOlderThan(cutoffDate))

        XCTAssertNil(newState.byId["old"])
        XCTAssertNotNil(newState.byId["recent"])
        XCTAssertEqual(newState.allIds, ["recent"])
    }

    // MARK: - State Immutability Tests

    func test_reducerReturnsNewState_doesNotMutateOriginal() {
        let state = ArticleState()
        let article = makeTestArticle(id: "1")

        _ = articleReducer(state: state, action: ArticleAction.addArticles([article]))

        // Original state should remain empty
        XCTAssertTrue(state.byId.isEmpty)
        XCTAssertTrue(state.allIds.isEmpty)
    }
}
