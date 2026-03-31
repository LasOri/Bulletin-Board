import LINKER

extension ErrorMessage {

    public static func errorGPU(message: String, onDismiss: @escaping () -> Void) -> [AnyNode] {
        guard GPUComponentConfig.isEnabled(for: "ErrorMessage") else {
            GPUComponentConfig.log("ErrorMessage: GPU disabled, using standard render")
            return error(message: message, onDismiss: onDismiss)
        }

        GPUComponentConfig.log("ErrorMessage: Rendering with GPU shadow (elevation8)")

        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ErrorMessage") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            shadowStyle = .elevation8
        }

        let errorContent = error(message: message, onDismiss: onDismiss)

        return ShadowView(id: "error-message-shadow", style: shadowStyle) {
            return errorContent
        }
    }

    public static func warningGPU(message: String, onDismiss: @escaping () -> Void) -> [AnyNode] {
        guard GPUComponentConfig.isEnabled(for: "ErrorMessage") else {
            GPUComponentConfig.log("ErrorMessage: GPU disabled, using standard render")
            return warning(message: message, onDismiss: onDismiss)
        }

        GPUComponentConfig.log("ErrorMessage: Rendering warning with GPU shadow (elevation8)")

        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ErrorMessage") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            shadowStyle = .elevation8
        }

        let warningContent = warning(message: message, onDismiss: onDismiss)

        return ShadowView(id: "warning-message-shadow", style: shadowStyle) {
            return warningContent
        }
    }

    public static func infoGPU(message: String, onDismiss: @escaping () -> Void) -> [AnyNode] {
        guard GPUComponentConfig.isEnabled(for: "ErrorMessage") else {
            GPUComponentConfig.log("ErrorMessage: GPU disabled, using standard render")
            return info(message: message, onDismiss: onDismiss)
        }

        GPUComponentConfig.log("ErrorMessage: Rendering info with GPU shadow (elevation4)")

        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "ErrorMessage") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            shadowStyle = .elevation4
        }

        let infoContent = info(message: message, onDismiss: onDismiss)

        return ShadowView(id: "info-message-shadow", style: shadowStyle) {
            return infoContent
        }
    }
}

