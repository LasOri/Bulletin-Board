import Foundation

public struct GPUComponentConfig {

    nonisolated(unsafe) public static var enabled: Bool = false

    nonisolated(unsafe) public static var debugMode: Bool = false

    public enum PerformanceMode {
        case high

        case balanced

        case low
    }

    nonisolated(unsafe) public static var performanceMode: PerformanceMode = .balanced

    nonisolated(unsafe) public static var componentOverrides: [String: Bool] = [:]

    nonisolated(unsafe) public static var shadowStyles: [String: (elevation: Float, intensity: Float)] = [:]

    nonisolated(unsafe) public static var blurStyles: [String: (radius: Int, saturation: Float, brightness: Float)] = [:]

    public static func isEnabled(for component: String) -> Bool {
        if performanceMode == .low {
            return false
        }

        if let override = componentOverrides[component] {
            return override
        }

        return enabled
    }

    public static func shadowStyle(for component: String) -> (elevation: Float, intensity: Float)? {
        return shadowStyles[component]
    }

    public static func blurStyle(for component: String) -> (radius: Int, saturation: Float, brightness: Float)? {
        return blurStyles[component]
    }

    public static func log(_ message: String) {
        if debugMode {
            print("[GPUConfig] \(message)")
        }
    }

    public static func reset() {
        enabled = false
        debugMode = false
        performanceMode = .balanced
        componentOverrides.removeAll()
        shadowStyles.removeAll()
        blurStyles.removeAll()
    }

    public static func configureForHighPerformance() {
        enabled = true
        performanceMode = .high
        log("Configured for high performance")
    }

    public static func configureForLowPerformance() {
        enabled = false
        performanceMode = .low
        log("Configured for low performance (CSS fallback)")
    }

    public static func configureForBalanced() {
        enabled = true
        performanceMode = .balanced
        log("Configured for balanced performance")
    }
}

