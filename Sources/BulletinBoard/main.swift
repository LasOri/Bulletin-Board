import Foundation
import LINKER
import JavaScriptEventLoop

print("[swift] before installGlobalExecutor")

// Install the global executor FIRST, synchronously, before any async work.
JavaScriptEventLoop.installGlobalExecutor()

print("[swift] after installGlobalExecutor")
print("[swift] Bulletin Board - News Feed Reader")
print("[swift] Built with LINKER Framework")

// Spawn the async application startup.
Task { @MainActor in
    print("[swift] Task body started")
    await App.main()
}

print("[swift] after Task creation, returning from main")
