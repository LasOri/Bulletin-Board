import Foundation
import LINKER
#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

/// Orchestrates the App Store-like card expansion/collapse animation.
///
/// Animation uses direct DOM manipulation (clone + CSS transforms) outside
/// the reconciler tree. Once the spring settles, the reconciler takes over
/// to render `ArticleDetailView` at rest.
public final class CardExpansionController: @unchecked Sendable {

    public static let shared = CardExpansionController()

    /// Stored source rect for reverse animation
    private var sourceRect: (x: Double, y: Double, width: Double, height: Double)?

    /// Article ID currently being animated
    private var articleId: String?

    private init() {}

    // MARK: - Expand

    #if canImport(JavaScriptKit) && arch(wasm32)

    /// Begins the expand animation: captures the source card rect, creates a
    /// fixed-position clone + backdrop, and animates 0→1 via spring physics.
    public func beginExpand(articleId: String) {
        guard let document = SafeJSGlobal.global?.document.object else { return }

        // Find the source card element
        guard let cardEl = document.querySelector!("[data-article-id=\"\(articleId)\"]").object else {
            // No card found — skip animation, go straight to expanded
            appStore.dispatch(UIAction.beginExpanding(id: articleId))
            appStore.dispatch(UIAction.expandComplete)
            return
        }

        self.articleId = articleId

        // Capture source rect
        guard let rectObj = cardEl.getBoundingClientRect!().object else { return }
        let sx = rectObj.x.number ?? 0
        let sy = rectObj.y.number ?? 0
        let sw = rectObj.width.number ?? 0
        let sh = rectObj.height.number ?? 0
        sourceRect = (x: sx, y: sy, width: sw, height: sh)

        // Dispatch expanding state
        appStore.dispatch(UIAction.beginExpanding(id: articleId))

        // Create backdrop overlay
        let backdrop = document.createElement!("div").object!
        backdrop.className = .string("card-expansion-backdrop")
        backdrop.style.object?.setProperty!("opacity", "0")

        // Create clone of the card
        let clone = cardEl.cloneNode!(true).object!
        clone.className = .string("card-expansion-clone")
        clone.style.object?.setProperty!("position", "fixed")
        clone.style.object?.setProperty!("left", "\(sx)px")
        clone.style.object?.setProperty!("top", "\(sy)px")
        clone.style.object?.setProperty!("width", "\(sw)px")
        clone.style.object?.setProperty!("height", "\(sh)px")
        clone.style.object?.setProperty!("transform-origin", "top left")
        clone.style.object?.setProperty!("z-index", "10001")
        clone.style.object?.setProperty!("will-change", "transform")
        clone.style.object?.setProperty!("pointer-events", "none")

        // Append to body (outside reconciler tree)
        let body = document.body.object!
        _ = body.appendChild!(backdrop)
        _ = body.appendChild!(clone)

        // Hide original card
        cardEl.style.object?.setProperty!("opacity", "0")

        // Get viewport dimensions for target rect
        let vw = SafeJSGlobal.global?.innerWidth.number ?? 800
        let vh = SafeJSGlobal.global?.innerHeight.number ?? 600

        // Target: centered, max 800px wide, full viewport height
        let targetW = min(vw, 800.0)
        let targetH = vh
        let targetX = (vw - targetW) / 2.0
        let targetY = 0.0

        // Animate spring from 0→1
        GPUAnimationEngine.shared.animateSpring(
            id: "card-expand",
            from: 0,
            to: 1,
            config: ArticleAnimations.cardExpandTransform,
            onUpdate: { [weak self] progress in
                guard self != nil else { return }
                // Interpolate position and size
                let currentX = sx + (targetX - sx) * progress
                let currentY = sy + (targetY - sy) * progress
                let currentW = sw + (targetW - sw) * progress
                let currentH = sh + (targetH - sh) * progress

                // Apply as translate + scale from original position
                let scaleX = currentW / sw
                let scaleY = currentH / sh
                let translateX = currentX - sx
                let translateY = currentY - sy

                clone.style.object?.setProperty!("transform",
                    "translate(\(translateX)px, \(translateY)px) scale(\(scaleX), \(scaleY))")

                // Fade backdrop
                backdrop.style.object?.setProperty!("opacity", "\(progress)")

                // Border radius shrinks with expansion
                let radius = 12.0 * (1.0 - progress)
                clone.style.object?.setProperty!("border-radius", "\(radius)px")
            },
            onComplete: { [weak self] in
                self?.onExpandComplete(backdrop: backdrop, clone: clone)
            }
        )
    }

    private func onExpandComplete(backdrop: JSObject, clone: JSObject) {
        // Remove animation elements
        _ = backdrop.remove!()
        _ = clone.remove!()

        // Transition to reconciler-rendered detail view
        appStore.dispatch(UIAction.expandComplete)
    }

    // MARK: - Collapse

    /// Begins the collapse animation: clones the detail view, animates it
    /// back to the stored source card rect.
    public func beginCollapse() {
        guard let document = SafeJSGlobal.global?.document.object,
              let sourceRect = sourceRect else {
            // No source rect — skip animation
            appStore.dispatch(UIAction.collapseComplete)
            return
        }

        // Capture the detail card BEFORE dispatching (dispatch triggers re-render
        // via microtask which would remove it from the DOM).
        let detailEl = document.querySelector!(".article-detail").object

        // Dispatch collapsing state (removes detail view from reconciler tree on next microtask)
        appStore.dispatch(UIAction.beginCollapsing)

        // Get the detail view's current rect (or use viewport center)
        let vw = SafeJSGlobal.global?.innerWidth.number ?? 800
        let vh = SafeJSGlobal.global?.innerHeight.number ?? 600
        let dw = min(vw, 800.0)
        let dh = vh
        let dx = (vw - dw) / 2.0
        let dy = 0.0

        // Create backdrop
        let backdrop = document.createElement!("div").object!
        backdrop.className = .string("card-expansion-backdrop")
        backdrop.style.object?.setProperty!("opacity", "1")

        // Create clone from detail element or a placeholder
        let clone: JSObject
        if let detailEl = detailEl {
            clone = detailEl.cloneNode!(true).object!
        } else {
            clone = document.createElement!("div").object!
        }
        clone.className = .string("card-expansion-clone")
        clone.style.object?.setProperty!("position", "fixed")
        clone.style.object?.setProperty!("left", "\(dx)px")
        clone.style.object?.setProperty!("top", "\(dy)px")
        clone.style.object?.setProperty!("width", "\(dw)px")
        clone.style.object?.setProperty!("height", "\(dh)px")
        clone.style.object?.setProperty!("transform-origin", "top left")
        clone.style.object?.setProperty!("z-index", "10001")
        clone.style.object?.setProperty!("will-change", "transform")
        clone.style.object?.setProperty!("pointer-events", "none")
        clone.style.object?.setProperty!("overflow", "hidden")
        clone.style.object?.setProperty!("background", "var(--color-surface)")

        let body = document.body.object!
        _ = body.appendChild!(backdrop)
        _ = body.appendChild!(clone)

        let sx = sourceRect.x
        let sy = sourceRect.y
        let sw = sourceRect.width
        let sh = sourceRect.height

        // Animate spring 0→1 (representing detail→card)
        GPUAnimationEngine.shared.animateSpring(
            id: "card-collapse",
            from: 0,
            to: 1,
            config: ArticleAnimations.cardCollapseTransform,
            onUpdate: { progress in
                // Interpolate from detail rect to source card rect
                let currentX = dx + (sx - dx) * progress
                let currentY = dy + (sy - dy) * progress
                let currentW = dw + (sw - dw) * progress
                let currentH = dh + (sh - dh) * progress

                let scaleX = currentW / dw
                let scaleY = currentH / dh
                let translateX = currentX - dx
                let translateY = currentY - dy

                clone.style.object?.setProperty!("transform",
                    "translate(\(translateX)px, \(translateY)px) scale(\(scaleX), \(scaleY))")

                // Fade backdrop out
                backdrop.style.object?.setProperty!("opacity", "\(1.0 - progress)")

                // Border radius grows as it shrinks back to card
                let radius = 12.0 * progress
                clone.style.object?.setProperty!("border-radius", "\(radius)px")
            },
            onComplete: { [weak self] in
                self?.onCollapseComplete(backdrop: backdrop, clone: clone)
            }
        )
    }

    private func onCollapseComplete(backdrop: JSObject, clone: JSObject) {
        // Remove animation elements
        _ = backdrop.remove!()
        _ = clone.remove!()

        // Restore original card visibility
        if let articleId = articleId,
           let document = SafeJSGlobal.global?.document.object,
           let cardEl = document.querySelector!("[data-article-id=\"\(articleId)\"]").object {
            cardEl.style.object?.setProperty!("opacity", "1")
        }

        // Reset state
        self.articleId = nil
        self.sourceRect = nil

        appStore.dispatch(UIAction.collapseComplete)
    }

    // MARK: - Keyboard Dismiss

    /// Sets up Escape key listener for dismissing the detail view.
    /// Call once during app initialization.
    public func setupEscapeHandler(document: JSObject) {
        let handler = JSClosure { [weak self] args -> JSValue in
            guard args.count > 0,
                  let event = args[0].object,
                  event.key.string == "Escape" else {
                return .undefined
            }

            let phase = appStore.getState().ui.animationPhase
            if phase == .expanded {
                self?.beginCollapse()
            }

            return .undefined
        }
        document.addEventListener!("keydown", handler)
    }

    #else
    // Non-WASM stubs
    public func beginExpand(articleId: String) {
        appStore.dispatch(UIAction.beginExpanding(id: articleId))
        appStore.dispatch(UIAction.expandComplete)
    }

    public func beginCollapse() {
        appStore.dispatch(UIAction.collapseComplete)
    }

    public func setupEscapeHandler(document: Any) {}
    #endif
}
