import XCTest
@testable import BulletinBoard
import LINKER

final class ConfirmationDialogTests: XCTestCase {

    func test_render_containsMessage() {
        let props = ConfirmationDialog.Props(message: "Delete all articles?", pendingAction: "delete-older-7")
        let nodes = ConfirmationDialog.render(props: props)
        let html = renderToString(nodes)
        XCTAssertTrue(html.contains("Delete all articles?"))
    }

    func test_render_hasConfirmButton() {
        let props = ConfirmationDialog.Props(message: "Are you sure?", pendingAction: "archive-all-read")
        let nodes = ConfirmationDialog.render(props: props)
        let html = renderToString(nodes)
        XCTAssertTrue(html.contains("data-action=\"confirm-action\""))
        XCTAssertTrue(html.contains("Confirm"))
    }

    func test_render_hasCancelButton() {
        let props = ConfirmationDialog.Props(message: "Are you sure?", pendingAction: "archive-all-read")
        let nodes = ConfirmationDialog.render(props: props)
        let html = renderToString(nodes)
        XCTAssertTrue(html.contains("data-action=\"cancel-confirmation\""))
        XCTAssertTrue(html.contains("Cancel"))
    }

    func test_render_hasDialogRole() {
        let props = ConfirmationDialog.Props(message: "Test", pendingAction: "test")
        let nodes = ConfirmationDialog.render(props: props)
        let html = renderToString(nodes)
        XCTAssertTrue(html.contains("role=\"dialog\""))
        XCTAssertTrue(html.contains("aria-modal=\"true\""))
    }

    func test_render_includesPendingAction() {
        let props = ConfirmationDialog.Props(message: "Test", pendingAction: "delete-feed")
        let nodes = ConfirmationDialog.render(props: props)
        let html = renderToString(nodes)
        XCTAssertTrue(html.contains("data-pending-action=\"delete-feed\""))
    }

    func test_render_sanitizesMessage() {
        let props = ConfirmationDialog.Props(message: "<script>alert(1)</script>", pendingAction: "test")
        let nodes = ConfirmationDialog.render(props: props)
        let html = renderToString(nodes)
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }

    private func renderToString(_ nodes: [AnyNode]) -> String {
        nodes.map { $0.render() }.joined()
    }
}

final class ConfirmationStateTests: XCTestCase {

    func test_showConfirmation_setsState() {
        let state = UIState()
        let result = uiReducer(state: state, action: AnyAction(UIAction.showConfirmation(message: "Delete?", pendingAction: "delete-feed")))
        XCTAssertEqual(result.confirmationMessage, "Delete?")
        XCTAssertEqual(result.pendingAction, "delete-feed")
    }

    func test_cancelConfirmation_clearsState() {
        var state = UIState()
        state.confirmationMessage = "Delete?"
        state.pendingAction = "delete-feed"
        let result = uiReducer(state: state, action: AnyAction(UIAction.cancelConfirmation))
        XCTAssertNil(result.confirmationMessage)
        XCTAssertNil(result.pendingAction)
    }

    func test_confirmAction_clearsState() {
        var state = UIState()
        state.confirmationMessage = "Delete?"
        state.pendingAction = "delete-feed"
        let result = uiReducer(state: state, action: AnyAction(UIAction.confirmAction))
        XCTAssertNil(result.confirmationMessage)
        XCTAssertNil(result.pendingAction)
    }
}
