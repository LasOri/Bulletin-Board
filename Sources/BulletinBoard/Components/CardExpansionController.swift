import Foundation
import LINKER
#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

public final class CardExpansionController: @unchecked Sendable {

    public static let shared = CardExpansionController()

    private var sourceRect: (x: Double, y: Double, width: Double, height: Double)?

    private var articleId: String?

    private init() {}

    #if canImport(JavaScriptKit) && arch(wasm32)

    public func beginExpand(articleId: String) {
        guard let document = SafeJSGlobal.global?.document.object else { return }

        guard let cardEl = document.querySelector!("[data-article-id=\"\(articleId)\"]").object else {
            appStore.dispatch(UIAction.beginExpanding(id: articleId))
            appStore.dispatch(UIAction.expandComplete)
            return
        }

        self.articleId = articleId

        guard let rectObj = cardEl.getBoundingClientRect!().object else { return }
        let sx = rectObj.x.number ?? 0
        let sy = rectObj.y.number ?? 0
        let sw = rectObj.width.number ?? 0
        let sh = rectObj.height.number ?? 0
        sourceRect = (x: sx, y: sy, width: sw, height: sh)

        appStore.dispatch(UIAction.beginExpanding(id: articleId))

        let backdrop = document.createElement!("div").object!
        backdrop.className = .string("card-expansion-backdrop")
        backdrop.style.object?.setProperty!("opacity", "0")

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

        let body = document.body.object!
        _ = body.appendChild!(backdrop)
        _ = body.appendChild!(clone)

        cardEl.style.object?.setProperty!("opacity", "0")

        let vw = SafeJSGlobal.global?.innerWidth.number ?? 800
        let vh = SafeJSGlobal.global?.innerHeight.number ?? 600

        let targetW = min(vw, 800.0)
        let targetH = vh
        let targetX = (vw - targetW) / 2.0
        let targetY = 0.0

        GPUAnimationEngine.shared.animateSpring(
            id: "card-expand",
            from: 0,
            to: 1,
            config: ArticleAnimations.cardExpandTransform,
            onUpdate: { [weak self] progress in
                guard self != nil else { return }
                let currentX = sx + (targetX - sx) * progress
                let currentY = sy + (targetY - sy) * progress
                let currentW = sw + (targetW - sw) * progress
                let currentH = sh + (targetH - sh) * progress

                let scaleX = currentW / sw
                let scaleY = currentH / sh
                let translateX = currentX - sx
                let translateY = currentY - sy

                clone.style.object?.setProperty!("transform",
                    "translate(\(translateX)px, \(translateY)px) scale(\(scaleX), \(scaleY))")

                backdrop.style.object?.setProperty!("opacity", "\(progress)")

                let radius = 12.0 * (1.0 - progress)
                clone.style.object?.setProperty!("border-radius", "\(radius)px")
            },
            onComplete: { [weak self] in
                self?.onExpandComplete(backdrop: backdrop, clone: clone)
            }
        )
    }

    private func onExpandComplete(backdrop: JSObject, clone: JSObject) {
        _ = backdrop.remove!()
        _ = clone.remove!()

        appStore.dispatch(UIAction.expandComplete)
    }

    public func beginCollapse() {
        guard let document = SafeJSGlobal.global?.document.object,
              let sourceRect = sourceRect else {
            appStore.dispatch(UIAction.collapseComplete)
            return
        }

        let detailEl = document.querySelector!(".article-detail").object

        appStore.dispatch(UIAction.beginCollapsing)

        let vw = SafeJSGlobal.global?.innerWidth.number ?? 800
        let vh = SafeJSGlobal.global?.innerHeight.number ?? 600
        let dw = min(vw, 800.0)
        let dh = vh
        let dx = (vw - dw) / 2.0
        let dy = 0.0

        let backdrop = document.createElement!("div").object!
        backdrop.className = .string("card-expansion-backdrop")
        backdrop.style.object?.setProperty!("opacity", "1")

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

        GPUAnimationEngine.shared.animateSpring(
            id: "card-collapse",
            from: 0,
            to: 1,
            config: ArticleAnimations.cardCollapseTransform,
            onUpdate: { progress in
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

                backdrop.style.object?.setProperty!("opacity", "\(1.0 - progress)")

                let radius = 12.0 * progress
                clone.style.object?.setProperty!("border-radius", "\(radius)px")
            },
            onComplete: { [weak self] in
                self?.onCollapseComplete(backdrop: backdrop, clone: clone)
            }
        )
    }

    private func onCollapseComplete(backdrop: JSObject, clone: JSObject) {
        _ = backdrop.remove!()
        _ = clone.remove!()

        if let articleId = articleId,
           let document = SafeJSGlobal.global?.document.object,
           let cardEl = document.querySelector!("[data-article-id=\"\(articleId)\"]").object {
            cardEl.style.object?.setProperty!("opacity", "1")
        }

        self.articleId = nil
        self.sourceRect = nil

        appStore.dispatch(UIAction.collapseComplete)
    }

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

