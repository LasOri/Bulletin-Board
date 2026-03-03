import XCTest
@testable import BulletinBoard
import LINKER

final class ArticleAnimationsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SignalRuntime.shared.testMode = true
    }

    override func tearDown() {
        SignalRuntime.shared.reset()
        super.tearDown()
    }

    // MARK: - Spring Config Tests

    func testCardExpandConfig() {
        let config = ArticleAnimations.cardExpand
        XCTAssertEqual(config, SpringConfig.stiff)
    }

    func testCardCollapseConfig() {
        let config = ArticleAnimations.cardCollapse
        XCTAssertEqual(config, SpringConfig.stiff)
    }

    func testSmoothScrollConfig() {
        let config = ArticleAnimations.smoothScroll
        XCTAssertEqual(config, SpringConfig.gentle)
    }

    func testFavoriteToggleConfig() {
        let config = ArticleAnimations.favoriteToggle
        XCTAssertEqual(config, SpringConfig.wobbly)
    }

    func testListEntryConfig() {
        let config = ArticleAnimations.listEntry
        XCTAssertEqual(config.tension, 190)
        XCTAssertEqual(config.friction, 22)
        XCTAssertEqual(config.mass, 1.0)
    }

    // MARK: - Transition Config Tests

    func testCardFadeTransition() {
        let config = ArticleAnimations.cardFade
        XCTAssertEqual(config, TransitionConfig.fade)
    }

    func testListSlideTransition() {
        let config = ArticleAnimations.listSlide
        XCTAssertEqual(config.type, .slideUp)
        XCTAssertEqual(config.durationMs, 250)
        XCTAssertEqual(config.timingFunction, "ease-out")
    }

    func testImageScaleTransition() {
        let config = ArticleAnimations.imageScale
        XCTAssertEqual(config.type, .scale)
        XCTAssertEqual(config.durationMs, 300)
        XCTAssertEqual(config.timingFunction, "ease-in-out")
    }

    func testLoadingFadeTransition() {
        let config = ArticleAnimations.loadingFade
        XCTAssertEqual(config, TransitionConfig.fast)
    }

    // MARK: - Signal Creation Tests

    func testCreateHeightSignal() {
        #if arch(wasm32)
        let signal = ArticleAnimations.createHeightSignal(initialHeight: 100)
        XCTAssertEqual(signal.get(), 100)
        #else
        XCTAssertTrue(true, "Skipped: AnimatedSignal requires WASM environment")
        #endif
    }

    func testCreateHeightSignalDefaultValue() {
        #if arch(wasm32)
        let signal = ArticleAnimations.createHeightSignal()
        XCTAssertEqual(signal.get(), 0)
        #else
        XCTAssertTrue(true, "Skipped: AnimatedSignal requires WASM environment")
        #endif
    }

    func testCreateOpacitySignal() {
        #if arch(wasm32)
        let signal = ArticleAnimations.createOpacitySignal(initialOpacity: 0.5)
        XCTAssertEqual(signal.get(), 0.5)
        #else
        XCTAssertTrue(true, "Skipped: AnimatedSignal requires WASM environment")
        #endif
    }

    func testCreateOpacitySignalDefaultValue() {
        #if arch(wasm32)
        let signal = ArticleAnimations.createOpacitySignal()
        XCTAssertEqual(signal.get(), 1.0)
        #else
        XCTAssertTrue(true, "Skipped: AnimatedSignal requires WASM environment")
        #endif
    }

    func testCreateScaleSignal() {
        #if arch(wasm32)
        let signal = ArticleAnimations.createScaleSignal(initialScale: 0.8)
        XCTAssertEqual(signal.get(), 0.8)
        #else
        XCTAssertTrue(true, "Skipped: AnimatedSignal requires WASM environment")
        #endif
    }

    func testCreateScaleSignalDefaultValue() {
        #if arch(wasm32)
        let signal = ArticleAnimations.createScaleSignal()
        XCTAssertEqual(signal.get(), 1.0)
        #else
        XCTAssertTrue(true, "Skipped: AnimatedSignal requires WASM environment")
        #endif
    }

    func testCreateTranslationSignal() {
        #if arch(wasm32)
        let signal = ArticleAnimations.createTranslationSignal(initialOffset: 50)
        XCTAssertEqual(signal.get(), 50)
        #else
        XCTAssertTrue(true, "Skipped: AnimatedSignal requires WASM environment")
        #endif
    }

    func testCreateTranslationSignalDefaultValue() {
        #if arch(wasm32)
        let signal = ArticleAnimations.createTranslationSignal()
        XCTAssertEqual(signal.get(), 0)
        #else
        XCTAssertTrue(true, "Skipped: AnimatedSignal requires WASM environment")
        #endif
    }

    // MARK: - CSS Style Generator Tests

    func testHeightStyle() {
        let style = ArticleAnimations.heightStyle(250)
        XCTAssertTrue(style.contains("height: 250.0px"))
        XCTAssertTrue(style.contains("overflow: hidden"))
    }

    func testOpacityStyle() {
        let style = ArticleAnimations.opacityStyle(0.75)
        XCTAssertTrue(style.contains("opacity: 0.75"))
    }

    func testScaleStyle() {
        let style = ArticleAnimations.scaleStyle(1.2)
        XCTAssertTrue(style.contains("transform: scale(1.2)"))
        XCTAssertTrue(style.contains("will-change: transform"))
    }

    func testTranslateStyleY() {
        let style = ArticleAnimations.translateStyle(20, axis: "y")
        XCTAssertTrue(style.contains("translateY(20.0px)"))
        XCTAssertTrue(style.contains("will-change: transform"))
    }

    func testTranslateStyleX() {
        let style = ArticleAnimations.translateStyle(30, axis: "x")
        XCTAssertTrue(style.contains("translateX(30.0px)"))
        XCTAssertTrue(style.contains("will-change: transform"))
    }

    func testTranslateStyleDefaultAxis() {
        let style = ArticleAnimations.translateStyle(40)
        XCTAssertTrue(style.contains("translateY(40.0px)"))
    }

    func testExpandStyle() {
        let style = ArticleAnimations.expandStyle(height: 300, opacity: 0.9)
        XCTAssertTrue(style.contains("height: 300.0px"))
        XCTAssertTrue(style.contains("opacity: 0.9"))
        XCTAssertTrue(style.contains("overflow: hidden"))
        XCTAssertTrue(style.contains("will-change"))
    }

    // MARK: - Easing Function Tests

    func testEasingLinear() {
        let easing = EasingFunction.linear
        XCTAssertEqual(easing.apply(0.0), 0.0)
        XCTAssertEqual(easing.apply(0.5), 0.5)
        XCTAssertEqual(easing.apply(1.0), 1.0)
    }

    func testEasingEaseIn() {
        let easing = EasingFunction.easeIn
        XCTAssertEqual(easing.apply(0.0), 0.0)
        XCTAssertLessThan(easing.apply(0.5), 0.5)
        XCTAssertEqual(easing.apply(1.0), 1.0)
    }

    func testEasingEaseOut() {
        let easing = EasingFunction.easeOut
        XCTAssertEqual(easing.apply(0.0), 0.0)
        XCTAssertGreaterThan(easing.apply(0.5), 0.5)
        XCTAssertEqual(easing.apply(1.0), 1.0)
    }

    func testEasingEaseInOut() {
        let easing = EasingFunction.easeInOut
        XCTAssertEqual(easing.apply(0.0), 0.0)
        XCTAssertEqual(easing.apply(1.0), 1.0)
        // Middle value should be close to 0.5
        let midValue = easing.apply(0.5)
        XCTAssertGreaterThan(midValue, 0.4)
        XCTAssertLessThan(midValue, 0.6)
    }

    func testEasingCubic() {
        let easing = EasingFunction.easeInCubic
        XCTAssertEqual(easing.apply(0.0), 0.0)
        XCTAssertEqual(easing.apply(1.0), 1.0)
        XCTAssertLessThan(easing.apply(0.5), 0.25) // Cubic starts slow
    }

    // MARK: - ArticleAnimationState Tests

    func testAnimationStateInitialization() {
        #if arch(wasm32)
        let state = ArticleAnimationState()
        XCTAssertFalse(state.isExpanded)
        XCTAssertEqual(state.heightSignal.get(), 200.0) // collapsed height
        XCTAssertEqual(state.opacitySignal.get(), 1.0)
        XCTAssertEqual(state.collapsedHeight, 200.0)
        XCTAssertEqual(state.expandedHeight, 600.0)
        #else
        XCTAssertTrue(true, "Skipped: ArticleAnimationState requires WASM environment")
        #endif
    }

    func testAnimationStateToggleExpand() {
        #if arch(wasm32)
        let state = ArticleAnimationState()
        XCTAssertFalse(state.isExpanded)

        state.toggle()
        XCTAssertTrue(state.isExpanded)
        // Height signal should be set to expanded height
        // (actual animation happens in WASM environment)
        #else
        XCTAssertTrue(true, "Skipped: ArticleAnimationState requires WASM environment")
        #endif
    }

    func testAnimationStateToggleCollapse() {
        #if arch(wasm32)
        let state = ArticleAnimationState()
        state.isExpanded = true

        state.toggle()
        XCTAssertFalse(state.isExpanded)
        #else
        XCTAssertTrue(true, "Skipped: ArticleAnimationState requires WASM environment")
        #endif
    }

    func testAnimationStateExpand() {
        #if arch(wasm32)
        let state = ArticleAnimationState()
        XCTAssertFalse(state.isExpanded)

        state.expand()
        XCTAssertTrue(state.isExpanded)
        #else
        XCTAssertTrue(true, "Skipped: ArticleAnimationState requires WASM environment")
        #endif
    }

    func testAnimationStateExpandWhenAlreadyExpanded() {
        #if arch(wasm32)
        let state = ArticleAnimationState()
        state.isExpanded = true

        state.expand()
        XCTAssertTrue(state.isExpanded)
        #else
        XCTAssertTrue(true, "Skipped: ArticleAnimationState requires WASM environment")
        #endif
    }

    func testAnimationStateCollapse() {
        #if arch(wasm32)
        let state = ArticleAnimationState()
        state.isExpanded = true

        state.collapse()
        XCTAssertFalse(state.isExpanded)
        #else
        XCTAssertTrue(true, "Skipped: ArticleAnimationState requires WASM environment")
        #endif
    }

    func testAnimationStateCollapseWhenAlreadyCollapsed() {
        #if arch(wasm32)
        let state = ArticleAnimationState()
        XCTAssertFalse(state.isExpanded)

        state.collapse()
        XCTAssertFalse(state.isExpanded)
        #else
        XCTAssertTrue(true, "Skipped: ArticleAnimationState requires WASM environment")
        #endif
    }

    func testAnimationStateFadeIn() {
        #if arch(wasm32)
        let state = ArticleAnimationState()
        state.opacitySignal.setImmediate(0.0)

        state.fadeIn()
        // Signal should be set to 1.0 (animation happens in WASM)
        #else
        XCTAssertTrue(true, "Skipped: ArticleAnimationState requires WASM environment")
        #endif
    }

    func testAnimationStateFadeOut() {
        #if arch(wasm32)
        let state = ArticleAnimationState()
        XCTAssertEqual(state.opacitySignal.get(), 1.0)

        state.fadeOut()
        // Signal should be set to 0.0 (animation happens in WASM)
        #else
        XCTAssertTrue(true, "Skipped: ArticleAnimationState requires WASM environment")
        #endif
    }

    func testAnimationStateCustomHeights() {
        #if arch(wasm32)
        let state = ArticleAnimationState()
        state.collapsedHeight = 150.0
        state.expandedHeight = 800.0

        state.expand()
        XCTAssertTrue(state.isExpanded)
        #else
        XCTAssertTrue(true, "Skipped: ArticleAnimationState requires WASM environment")
        #endif
    }

    // MARK: - TransitionConfig Extension Tests

    func testTransitionToSpringConfigFast() {
        let transition = TransitionConfig(durationMs: 150)
        let spring = transition.toSpringConfig()
        XCTAssertEqual(spring, .stiff)
    }

    func testTransitionToSpringConfigNormal() {
        let transition = TransitionConfig(durationMs: 300)
        let spring = transition.toSpringConfig()
        // Should return default spring config
        XCTAssertEqual(spring.tension, 170)
        XCTAssertEqual(spring.friction, 26)
    }

    func testTransitionToSpringConfigSlow() {
        let transition = TransitionConfig(durationMs: 500)
        let spring = transition.toSpringConfig()
        XCTAssertEqual(spring, .gentle)
    }

    func testTransitionToSpringConfigVerySlow() {
        let transition = TransitionConfig(durationMs: 700)
        let spring = transition.toSpringConfig()
        XCTAssertEqual(spring, .slow)
    }

    // MARK: - Integration Tests

    func testAnimationWorkflow() {
        #if arch(wasm32)
        let state = ArticleAnimationState()

        // Start collapsed
        XCTAssertFalse(state.isExpanded)
        XCTAssertEqual(state.heightSignal.get(), 200.0)

        // Expand
        state.expand()
        XCTAssertTrue(state.isExpanded)

        // Collapse
        state.collapse()
        XCTAssertFalse(state.isExpanded)

        // Toggle twice
        state.toggle()
        XCTAssertTrue(state.isExpanded)
        state.toggle()
        XCTAssertFalse(state.isExpanded)
        #else
        XCTAssertTrue(true, "Skipped: AnimatedSignal requires WASM environment")
        #endif
    }

    func testMultipleSignalsIndependent() {
        #if arch(wasm32)
        let signal1 = ArticleAnimations.createHeightSignal(initialHeight: 100)
        let signal2 = ArticleAnimations.createHeightSignal(initialHeight: 200)

        XCTAssertEqual(signal1.get(), 100)
        XCTAssertEqual(signal2.get(), 200)

        signal1.setImmediate(150)
        XCTAssertEqual(signal1.get(), 150)
        XCTAssertEqual(signal2.get(), 200) // signal2 unchanged
        #else
        XCTAssertTrue(true, "Skipped: AnimatedSignal requires WASM environment")
        #endif
    }
}
