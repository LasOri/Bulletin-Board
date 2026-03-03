import Foundation

/// Central configuration for GPU-powered visual effects.
///
/// Controls GPU features across all components with feature flags,
/// performance modes, and component-specific overrides.
///
/// # Example
/// ```swift
/// // Enable GPU effects
/// GPUComponentConfig.enabled = true
/// GPUComponentConfig.performanceMode = .balanced
///
/// // Disable for specific component
/// GPUComponentConfig.componentOverrides["ArticleCard"] = false
/// ```
public struct GPUComponentConfig {

    // MARK: - Feature Flags

    /// Master toggle for all GPU effects.
    /// When false, all components fall back to CSS.
    nonisolated(unsafe) public static var enabled: Bool = false

    /// Debug mode: enables verbose logging for GPU operations.
    nonisolated(unsafe) public static var debugMode: Bool = false

    // MARK: - Performance Mode

    /// Performance mode affects GPU effect quality and usage.
    public enum PerformanceMode {
        /// All GPU effects at highest quality
        case high

        /// GPU effects only for visible elements (default)
        case balanced

        /// CSS fallback for all effects
        case low
    }

    /// Current performance mode setting.
    nonisolated(unsafe) public static var performanceMode: PerformanceMode = .balanced

    // MARK: - Component Overrides

    /// Component-specific GPU effect overrides.
    /// Keys: component name (e.g., "ArticleCard")
    /// Values: enabled state (nil = use global setting)
    nonisolated(unsafe) public static var componentOverrides: [String: Bool] = [:]

    /// Custom shadow styles per component.
    /// Keys: component name
    /// Values: shadow elevation and intensity
    nonisolated(unsafe) public static var shadowStyles: [String: (elevation: Float, intensity: Float)] = [:]

    /// Custom blur styles per component.
    /// Keys: component name
    /// Values: blur radius, saturation, brightness
    nonisolated(unsafe) public static var blurStyles: [String: (radius: Int, saturation: Float, brightness: Float)] = [:]

    // MARK: - Helpers

    /// Checks if GPU effects are enabled for a specific component.
    public static func isEnabled(for component: String) -> Bool {
        // Check performance mode first (low mode disables all GPU)
        if performanceMode == .low {
            return false
        }

        // Check component-specific override
        if let override = componentOverrides[component] {
            return override
        }

        // Use global setting
        return enabled
    }

    /// Gets shadow style for a component.
    /// Returns nil if no custom style is set.
    public static func shadowStyle(for component: String) -> (elevation: Float, intensity: Float)? {
        return shadowStyles[component]
    }

    /// Gets blur style for a component.
    /// Returns nil if no custom style is set.
    public static func blurStyle(for component: String) -> (radius: Int, saturation: Float, brightness: Float)? {
        return blurStyles[component]
    }

    /// Logs debug message if debug mode is enabled.
    public static func log(_ message: String) {
        if debugMode {
            print("[GPUConfig] \(message)")
        }
    }

    // MARK: - Presets

    /// Resets all configuration to defaults.
    public static func reset() {
        enabled = false
        debugMode = false
        performanceMode = .balanced
        componentOverrides.removeAll()
        shadowStyles.removeAll()
        blurStyles.removeAll()
    }

    /// Configures for high-performance devices.
    public static func configureForHighPerformance() {
        enabled = true
        performanceMode = .high
        log("Configured for high performance")
    }

    /// Configures for low-end devices.
    public static func configureForLowPerformance() {
        enabled = false
        performanceMode = .low
        log("Configured for low performance (CSS fallback)")
    }

    /// Configures for balanced performance (recommended).
    public static func configureForBalanced() {
        enabled = true
        performanceMode = .balanced
        log("Configured for balanced performance")
    }
}
