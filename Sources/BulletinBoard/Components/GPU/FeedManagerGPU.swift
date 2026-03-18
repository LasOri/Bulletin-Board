import Foundation
import LINKER

extension FeedManager {

    public static func renderGPU(props: Props) -> [AnyNode] {
        guard GPUComponentConfig.isEnabled(for: "FeedManager") else {
            GPUComponentConfig.log("FeedManager: GPU disabled, using standard render")
            return render(props: props)
        }

        GPUComponentConfig.log("FeedManager: Rendering with GPU blur + shadow (iOS modal)")

        let blurStyle: BlurStyle
        if let custom = GPUComponentConfig.blurStyle(for: "FeedManager") {
            blurStyle = .custom(
                radius: custom.radius,
                saturation: custom.saturation,
                brightness: custom.brightness
            )
        } else {
            blurStyle = .frostedGlass
        }

        let shadowStyle: ShadowStyle
        if let custom = GPUComponentConfig.shadowStyle(for: "FeedManager") {
            shadowStyle = .custom(elevation: custom.elevation, intensity: custom.intensity)
        } else {
            shadowStyle = .elevation24
        }

        let modalContent = render(props: props)

        return BlurView(id: "feed-manager-blur", style: blurStyle, intensity: 0.8, animated: true) {
            return ShadowView(id: "feed-manager-shadow", style: shadowStyle) {
                return modalContent
            }
        }
    }
}

