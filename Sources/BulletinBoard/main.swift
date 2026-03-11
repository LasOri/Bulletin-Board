import Foundation
import LINKER

#if canImport(JavaScriptKit) && arch(wasm32)
import JavaScriptKit
import JavaScriptEventLoop

// Use direct JS console.log — bypasses Swift I/O buffering entirely
func jsLog(_ msg: String) {
    _ = JSObject.global.console.log(JSValue.string(msg))
}

// Install the global executor.
// Swift 6.3+: Uses ExecutorFactory API (no GOT hook issues)
JavaScriptEventLoop.installGlobalExecutor()

print("[swift] Bulletin Board - News Feed Reader")
print("[swift] Built with LINKER Framework")

Task {
    await App.main()
}

#else
// Non-WASM: no event loop or JS runtime available
print("Bulletin Board - Native mode (no WASM)")
#endif
