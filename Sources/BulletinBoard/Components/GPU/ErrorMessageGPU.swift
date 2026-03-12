import Foundation
import LINKER

/// GPU-enhanced ErrorMessage component extension.
///
/// Wraps error messages with elevated GPU shadow for prominence.
extension ErrorMessage {

    /// Renders error message with GPU-accelerated shadow for prominence.
    ///
    /// Error messages get higher elevation to draw attention
    /// and signal importance.
    ///
    /// # Example
    /// ```swift
    /// let errorNodes = ErrorMessage.errorGPU(
    ///     message: "Failed to load feed",
    ///     onDismiss: { }
    /// )
    /// ```
    ///
    /// # Performance
    /// - GPU mode: WebGPU shadow
    /// - Fallback: CSS box-shadow
    /// - Elevation: 8 (dialog-level prominence)
    /// - Use case: Alerts and error notifications

    /// Renders error message with GPU effects.
    public static func errorGPU(message: String, onDismiss: @escaping () -> Void) -> [AnyNode] {
        // Check if GPU is enabled for this component
        guard GPUComponentConfig.isEnabled(for: "ErrorMessage") else {
            GPUComponentConfig.log("ErrorMessage: GPU disabled, using standard render")
            return error(message: message, onDismiss: onDismiss)
        }

        GPUComponentConfig.log("ErrorMessage: Rendering with GPU shadow (elevation8)")

        // Get custom shadow style if configured
        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ErrorMessage") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            // Default: elevation8 for dialog-level prominence
            shadowStyle = .elevation8
        }

        // Render original error message
        let errorContent = error(message: message, onDismiss: onDismiss)

        // Wrap with GPU shadow
        return ShadowView(id: "error-message-shadow", style: shadowStyle) {
            return errorContent
        }
    }

    /// Renders warning message with GPU effects.
    public static func warningGPU(message: String, onDismiss: @escaping () -> Void) -> [AnyNode] {
        // Check if GPU is enabled for this component
        guard GPUComponentConfig.isEnabled(for: "ErrorMessage") else {
            GPUComponentConfig.log("ErrorMessage: GPU disabled, using standard render")
            return warning(message: message, onDismiss: onDismiss)
        }

        GPUComponentConfig.log("ErrorMessage: Rendering warning with GPU shadow (elevation8)")

        // Get custom shadow style if configured
        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ErrorMessage") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            // Default: elevation8 for dialog-level prominence
            shadowStyle = .elevation8
        }

        // Render original warning message
        let warningContent = warning(message: message, onDismiss: onDismiss)

        // Wrap with GPU shadow
        return ShadowView(id: "warning-message-shadow", style: shadowStyle) {
            return warningContent
        }
    }

    /// Renders info message with GPU effects.
    public static func infoGPU(message: String, onDismiss: @escaping () -> Void) -> [AnyNode] {
        // Check if GPU is enabled for this component
        guard GPUComponentConfig.isEnabled(for: "ErrorMessage") else {
            GPUComponentConfig.log("ErrorMessage: GPU disabled, using standard render")
            return info(message: message, onDismiss: onDismiss)
        }

        GPUComponentConfig.log("ErrorMessage: Rendering info with GPU shadow (elevation4)")

        // Get custom shadow style if configured (info gets less elevation)
        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ErrorMessage") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            // Default: elevation4 for info (less prominent than error)
            shadowStyle = .elevation4
        }

        // Render original info message
        let infoContent = info(message: message, onDismiss: onDismiss)

        // Wrap with GPU shadow
        return ShadowView(id: "info-message-shadow", style: shadowStyle) {
            return infoContent
        }
    }
}
