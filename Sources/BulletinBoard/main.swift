import Foundation
import LINKER

#if canImport(JavaScriptKit) && arch(wasm32)
import JavaScriptKit
import JavaScriptEventLoop

JavaScriptEventLoop.installGlobalExecutor()

print("[swift] Bulletin Board - News Feed Reader")
print("[swift] Built with LINKER Framework")

Task {
    await App.main()
}

#else
print("Bulletin Board - Native mode (no WASM)")
#endif

