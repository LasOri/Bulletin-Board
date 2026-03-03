import XCTest
@testable import BulletinBoard

/// Tests for GPUComponentConfig central configuration.
final class GPUComponentConfigTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset to defaults before each test
        GPUComponentConfig.reset()
    }

    // MARK: - Feature Flags

    func testDefaultConfiguration() {
        XCTAssertFalse(GPUComponentConfig.enabled, "GPU should be disabled by default")
        XCTAssertFalse(GPUComponentConfig.debugMode, "Debug mode should be disabled by default")
        XCTAssertEqual(GPUComponentConfig.performanceMode, .balanced, "Default should be balanced mode")
    }

    func testMasterToggle() {
        GPUComponentConfig.enabled = true
        XCTAssertTrue(GPUComponentConfig.enabled, "GPU should be enabled")

        GPUComponentConfig.enabled = false
        XCTAssertFalse(GPUComponentConfig.enabled, "GPU should be disabled")
    }

    func testDebugMode() {
        GPUComponentConfig.debugMode = true
        XCTAssertTrue(GPUComponentConfig.debugMode, "Debug mode should be enabled")
    }

    // MARK: - Performance Modes

    func testPerformanceModeHigh() {
        GPUComponentConfig.performanceMode = .high
        XCTAssertEqual(GPUComponentConfig.performanceMode, .high)
    }

    func testPerformanceModeBalanced() {
        GPUComponentConfig.performanceMode = .balanced
        XCTAssertEqual(GPUComponentConfig.performanceMode, .balanced)
    }

    func testPerformanceModeLow() {
        GPUComponentConfig.performanceMode = .low
        XCTAssertEqual(GPUComponentConfig.performanceMode, .low)
    }

    // MARK: - Component Overrides

    func testComponentOverrides() {
        GPUComponentConfig.enabled = true
        GPUComponentConfig.componentOverrides["TestComponent"] = false

        XCTAssertFalse(
            GPUComponentConfig.isEnabled(for: "TestComponent"),
            "Component override should disable GPU for specific component"
        )
    }

    func testComponentOverrideTrue() {
        GPUComponentConfig.enabled = false
        GPUComponentConfig.componentOverrides["TestComponent"] = true

        XCTAssertTrue(
            GPUComponentConfig.isEnabled(for: "TestComponent"),
            "Component override should enable GPU for specific component"
        )
    }

    func testIsEnabledUsesGlobalWhenNoOverride() {
        GPUComponentConfig.enabled = true

        XCTAssertTrue(
            GPUComponentConfig.isEnabled(for: "TestComponent"),
            "Should use global setting when no override"
        )
    }

    func testLowPerformanceModeDisablesAllComponents() {
        GPUComponentConfig.enabled = true
        GPUComponentConfig.performanceMode = .low

        XCTAssertFalse(
            GPUComponentConfig.isEnabled(for: "TestComponent"),
            "Low performance mode should disable GPU for all components"
        )
    }

    // MARK: - Shadow Styles

    func testCustomShadowStyle() {
        GPUComponentConfig.shadowStyles["TestComponent"] = (elevation: 10.0, intensity: 0.5)

        let style = GPUComponentConfig.shadowStyle(for: "TestComponent")
        XCTAssertNotNil(style)
        XCTAssertEqual(style?.elevation, 10.0)
        XCTAssertEqual(style?.intensity, 0.5)
    }

    func testShadowStyleReturnsNilWhenNotSet() {
        let style = GPUComponentConfig.shadowStyle(for: "NonExistent")
        XCTAssertNil(style, "Should return nil when no custom style is set")
    }

    // MARK: - Blur Styles

    func testCustomBlurStyle() {
        GPUComponentConfig.blurStyles["TestComponent"] = (radius: 15, saturation: 1.8, brightness: 1.2)

        let style = GPUComponentConfig.blurStyle(for: "TestComponent")
        XCTAssertNotNil(style)
        XCTAssertEqual(style?.radius, 15)
        XCTAssertEqual(style?.saturation, 1.8)
        XCTAssertEqual(style?.brightness, 1.2)
    }

    func testBlurStyleReturnsNilWhenNotSet() {
        let style = GPUComponentConfig.blurStyle(for: "NonExistent")
        XCTAssertNil(style, "Should return nil when no custom style is set")
    }

    // MARK: - Presets

    func testConfigureForHighPerformance() {
        GPUComponentConfig.configureForHighPerformance()

        XCTAssertTrue(GPUComponentConfig.enabled, "High performance should enable GPU")
        XCTAssertEqual(GPUComponentConfig.performanceMode, .high)
    }

    func testConfigureForLowPerformance() {
        GPUComponentConfig.configureForLowPerformance()

        XCTAssertFalse(GPUComponentConfig.enabled, "Low performance should disable GPU")
        XCTAssertEqual(GPUComponentConfig.performanceMode, .low)
    }

    func testConfigureForBalanced() {
        GPUComponentConfig.configureForBalanced()

        XCTAssertTrue(GPUComponentConfig.enabled, "Balanced should enable GPU")
        XCTAssertEqual(GPUComponentConfig.performanceMode, .balanced)
    }

    func testReset() {
        // Set everything to non-default values
        GPUComponentConfig.enabled = true
        GPUComponentConfig.debugMode = true
        GPUComponentConfig.performanceMode = .high
        GPUComponentConfig.componentOverrides["Test"] = true
        GPUComponentConfig.shadowStyles["Test"] = (elevation: 5, intensity: 0.3)
        GPUComponentConfig.blurStyles["Test"] = (radius: 10, saturation: 1.5, brightness: 1.0)

        // Reset
        GPUComponentConfig.reset()

        // Verify all back to defaults
        XCTAssertFalse(GPUComponentConfig.enabled)
        XCTAssertFalse(GPUComponentConfig.debugMode)
        XCTAssertEqual(GPUComponentConfig.performanceMode, .balanced)
        XCTAssertTrue(GPUComponentConfig.componentOverrides.isEmpty)
        XCTAssertTrue(GPUComponentConfig.shadowStyles.isEmpty)
        XCTAssertTrue(GPUComponentConfig.blurStyles.isEmpty)
    }

    // MARK: - Integration Tests

    func testMultipleComponentOverrides() {
        GPUComponentConfig.enabled = true
        GPUComponentConfig.componentOverrides["Component1"] = false
        GPUComponentConfig.componentOverrides["Component2"] = true
        GPUComponentConfig.componentOverrides["Component3"] = false

        XCTAssertFalse(GPUComponentConfig.isEnabled(for: "Component1"))
        XCTAssertTrue(GPUComponentConfig.isEnabled(for: "Component2"))
        XCTAssertFalse(GPUComponentConfig.isEnabled(for: "Component3"))
        XCTAssertTrue(GPUComponentConfig.isEnabled(for: "Component4"), "No override uses global")
    }

    func testPerformanceModeOverridesGlobal() {
        GPUComponentConfig.enabled = true
        GPUComponentConfig.performanceMode = .low
        GPUComponentConfig.componentOverrides["Component1"] = true

        // Low performance mode overrides even component overrides
        XCTAssertFalse(
            GPUComponentConfig.isEnabled(for: "Component1"),
            "Low performance mode should override component override"
        )
    }
}
