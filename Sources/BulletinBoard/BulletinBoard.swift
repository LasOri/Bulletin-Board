import Foundation
import LINKER
import JavaScriptEventLoop

/// The main entry point for Bulletin Board application.
///
/// Bulletin Board is a modern news feed reader built with LINKER framework,
/// demonstrating Swift WASM capabilities, reactive UI patterns, and local NLP processing.
@main
struct BulletinBoard {
    static func main() {
        JavaScriptEventLoop.installGlobalExecutor()

        print("🗞️ Bulletin Board - News Feed Reader")
        print("Built with LINKER Framework")
        print("https://github.com/LasOri/LINKER")

        Task { @MainActor in
            await App.main()
        }
    }
}
