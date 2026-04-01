import LINKER
#if canImport(JavaScriptKit) && arch(wasm32)
import JavaScriptKit
#endif

public final class CardExpansionController: @unchecked Sendable {

    public static let shared = CardExpansionController()

    private var sourceRect: (x: Double, y: Double, width: Double, height: Double)?

    private var articleId: String?

    private enum Constants {
        static let maxDetailWidth = 800.0
        static let cardBorderRadius = 12.0
        static let animationZIndex = 10001
        static let defaultViewportWidth = 800.0
        static let defaultViewportHeight = 600.0

        static let cloneClassName = "card-expansion-clone"
        static let backdropClassName = "card-expansion-backdrop"
        static let expandAnimationId = "card-expand"
        static let collapseAnimationId = "card-collapse"
        static let detailSelector = ".article-detail"
        static let escapeKey = "Escape"
        static let keydownEvent = "keydown"
    }

    private init() {}

    #if canImport(JavaScriptKit) && arch(wasm32)

    private func setStyle(_ element: JSObject, _ property: String, _ value: String) {
        _ = try? element.style.throwing.setProperty?(property, value)
    }

    private func styleCloneElement(_ clone: JSObject, x: Double, y: Double, width: Double, height: Double) {
        clone.className = .string(Constants.cloneClassName)
        setStyle(clone, "position", "fixed")
        setStyle(clone, "left", "\(x)px")
        setStyle(clone, "top", "\(y)px")
        setStyle(clone, "width", "\(width)px")
        setStyle(clone, "height", "\(height)px")
        setStyle(clone, "transform-origin", "top left")
        setStyle(clone, "z-index", "\(Constants.animationZIndex)")
        setStyle(clone, "will-change", "transform")
        setStyle(clone, "pointer-events", "none")
    }

    private func animateTransform(
        id: String,
        config: SpringAnimationConfig,
        sourceX: Double,
        sourceY: Double,
        sourceW: Double,
        sourceH: Double,
        targetX: Double,
        targetY: Double,
        targetW: Double,
        targetH: Double,
        forward: Bool,
        clone: JSObject,
        backdrop: JSObject,
        onComplete: @escaping () -> Void
    ) {
        GPUAnimationEngine.shared.animateSpring(
            id: id,
            from: 0,
            to: 1,
            config: config,
            onUpdate: { progress in
                let currentX = sourceX + (targetX - sourceX) * progress
                let currentY = sourceY + (targetY - sourceY) * progress
                let currentW = sourceW + (targetW - sourceW) * progress
                let currentH = sourceH + (targetH - sourceH) * progress

                let scaleX = currentW / sourceW
                let scaleY = currentH / sourceH
                let translateX = currentX - sourceX
                let translateY = currentY - sourceY

                setStyle(clone, "transform", "translate(\(translateX)px, \(translateY)px) scale(\(scaleX), \(scaleY))")
                setStyle(backdrop, "opacity", "\(forward ? progress : 1.0 - progress)")

                let radius = Constants.cardBorderRadius * (forward ? (1.0 - progress) : progress)
                setStyle(clone, "border-radius", "\(radius)px")
            },
            onComplete: onComplete
        )
    }

    public func beginExpand(articleId: String) {
        guard let document = SafeJSGlobal.global?.document.object else { return }

        guard let cardEl = (try? document.throwing.querySelector?("[data-article-id=\"\(articleId)\"]"))?.object else {
            appStore.dispatch(UIAction.beginExpanding(id: articleId))
            appStore.dispatch(UIAction.expandComplete)
            return
        }

        self.articleId = articleId

        guard let rectObj = (try? cardEl.throwing.getBoundingClientRect?())?.object else { return }
        let sx = rectObj.x.number ?? 0
        let sy = rectObj.y.number ?? 0
        let sw = rectObj.width.number ?? 0
        let sh = rectObj.height.number ?? 0
        sourceRect = (x: sx, y: sy, width: sw, height: sh)

        appStore.dispatch(UIAction.beginExpanding(id: articleId))

        guard let backdrop = createBackdrop(document: document, opacity: "0") else { return }

        guard let clone = (try? cardEl.throwing.cloneNode?(true))?.object else { return }
        styleCloneElement(clone, x: sx, y: sy, width: sw, height: sh)

        guard appendAnimationElements(document: document, backdrop: backdrop, clone: clone) else { return }

        setStyle(cardEl, "opacity", "0")

        let targetRect = computeDetailViewportRect()

        animateTransform(
            id: Constants.expandAnimationId,
            config: ArticleAnimations.cardExpandTransform,
            sourceX: sx,
            sourceY: sy,
            sourceW: sw,
            sourceH: sh,
            targetX: targetRect.x,
            targetY: targetRect.y,
            targetW: targetRect.width,
            targetH: targetRect.height,
            forward: true,
            clone: clone,
            backdrop: backdrop,
            onComplete: { [weak self] in
                self?.onExpandComplete(backdrop: backdrop, clone: clone)
            }
        )
    }

    private func createBackdrop(document: JSObject, opacity: String) -> JSObject? {
        guard let backdrop = (try? document.throwing.createElement?("div"))?.object else { return nil }
        backdrop.className = .string(Constants.backdropClassName)
        setStyle(backdrop, "opacity", opacity)
        return backdrop
    }

    private func computeDetailViewportRect() -> (x: Double, y: Double, width: Double, height: Double) {
        let vw = SafeJSGlobal.global?.innerWidth.number ?? Constants.defaultViewportWidth
        let vh = SafeJSGlobal.global?.innerHeight.number ?? Constants.defaultViewportHeight
        let width = min(vw, Constants.maxDetailWidth)
        let height = vh
        let x = (vw - width) / 2.0
        let y = 0.0
        return (x: x, y: y, width: width, height: height)
    }

    private func appendAnimationElements(document: JSObject, backdrop: JSObject, clone: JSObject) -> Bool {
        guard let body = document.body.object else { return false }
        _ = try? body.throwing.appendChild?(backdrop)
        _ = try? body.throwing.appendChild?(clone)
        return true
    }

    private func cleanupAnimationElements(backdrop: JSObject, clone: JSObject) {
        _ = try? backdrop.throwing.remove?()
        _ = try? clone.throwing.remove?()
    }

    private func onExpandComplete(backdrop: JSObject, clone: JSObject) {
        cleanupAnimationElements(backdrop: backdrop, clone: clone)
        appStore.dispatch(UIAction.expandComplete)
    }

    public func beginCollapse() {
        guard let document = SafeJSGlobal.global?.document.object,
              let sourceRect = sourceRect else {
            appStore.dispatch(UIAction.collapseComplete)
            return
        }

        let detailEl = (try? document.throwing.querySelector?(Constants.detailSelector))?.object

        appStore.dispatch(UIAction.beginCollapsing)

        let detailRect = computeDetailViewportRect()

        guard let backdrop = createBackdrop(document: document, opacity: "1") else { return }

        let clone: JSObject
        if let detailEl = detailEl,
           let cloned = (try? detailEl.throwing.cloneNode?(true))?.object {
            clone = cloned
        } else if let created = (try? document.throwing.createElement?("div"))?.object {
            clone = created
        } else {
            return
        }
        styleCloneElement(clone, x: detailRect.x, y: detailRect.y, width: detailRect.width, height: detailRect.height)
        setStyle(clone, "overflow", "hidden")
        setStyle(clone, "background", "var(--color-surface)")

        guard appendAnimationElements(document: document, backdrop: backdrop, clone: clone) else { return }

        let sx = sourceRect.x
        let sy = sourceRect.y
        let sw = sourceRect.width
        let sh = sourceRect.height

        animateTransform(
            id: Constants.collapseAnimationId,
            config: ArticleAnimations.cardCollapseTransform,
            sourceX: detailRect.x,
            sourceY: detailRect.y,
            sourceW: detailRect.width,
            sourceH: detailRect.height,
            targetX: sx,
            targetY: sy,
            targetW: sw,
            targetH: sh,
            forward: false,
            clone: clone,
            backdrop: backdrop,
            onComplete: { [weak self] in
                self?.onCollapseComplete(backdrop: backdrop, clone: clone)
            }
        )
    }

    private func onCollapseComplete(backdrop: JSObject, clone: JSObject) {
        cleanupAnimationElements(backdrop: backdrop, clone: clone)

        if let articleId = articleId,
           let document = SafeJSGlobal.global?.document.object,
           let cardEl = (try? document.throwing.querySelector?("[data-article-id=\"\(articleId)\"]"))?.object {
            setStyle(cardEl, "opacity", "1")
        }

        self.articleId = nil
        self.sourceRect = nil

        appStore.dispatch(UIAction.collapseComplete)
    }

    public func setupEscapeHandler(document: JSObject) {
        let handler = JSClosure { [weak self] args -> JSValue in
            guard args.count > 0,
                  let event = args[0].object,
                  event.key.string == Constants.escapeKey else {
                return .undefined
            }

            let phase = appStore.getState().ui.animationPhase
            if phase == .expanded {
                self?.beginCollapse()
            }

            return .undefined
        }
        _ = try? document.throwing.addEventListener?(Constants.keydownEvent, handler)
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
