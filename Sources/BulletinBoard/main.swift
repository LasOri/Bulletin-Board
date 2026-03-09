import Foundation
import LINKER
import JavaScriptEventLoop

// Install the global executor FIRST, synchronously, before any async work.
// This hooks Swift concurrency into the JavaScript event loop via
// queueMicrotask/setTimeout so that Task bodies actually execute.
JavaScriptEventLoop.installGlobalExecutor()

print("🗞️ Bulletin Board - News Feed Reader")
print("Built with LINKER Framework")
print("https://github.com/LasOri/LINKER")

// Spawn the async application startup.
// The Task is enqueued via the JavaScriptEventLoop and will execute
// once control returns to the JS event loop (after this top-level code returns).
Task { @MainActor in
    await App.main()
}
