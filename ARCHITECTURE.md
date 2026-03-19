# Bulletin Board — Architecture & Build Guide

A full-stack Swift WebAssembly news feed reader, built on the **LINKER** reactive UI framework, compiled to WASM and running entirely in the browser with WebGPU-accelerated effects.

**Live site:** https://lasori.github.io/Bulletin-Board/

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Technology Stack](#technology-stack)
3. [LINKER Framework](#linker-framework)
4. [Swift-to-WASM Compilation](#swift-to-wasm-compilation)
5. [JavaScriptKit Patching](#javascriptkit-patching)
6. [The JavaScript Loader](#the-javascript-loader)
7. [WASM Binary Size Optimization](#wasm-binary-size-optimization)
8. [WebGPU Integration](#webgpu-integration)
9. [Service Worker & Caching](#service-worker--caching)
10. [Local Development](#local-development)
11. [Deployment](#deployment)
12. [Key Lessons Learned](#key-lessons-learned)

---

## Project Overview

Bulletin Board is a browser-based RSS/news reader where **every line of application logic is Swift**, compiled to WebAssembly. There is no React, no TypeScript, no npm bundler — just Swift source compiled to a `.wasm` binary, a hand-written JS bootstrap loader, and static HTML/CSS.

```
User's Browser
├── index.html          — Shell with <div id="app"> and loading spinner
├── styles.css          — All styling (1365 lines)
├── BulletinBoard.js    — JavaScriptKit runtime + WASI shims + WASM loader
├── BulletinBoard.wasm  — 48 MB optimized binary (entire app + LINKER framework)
└── sw.js               — Service worker (stale-while-revalidate caching)
```

The Swift code handles:
- RSS feed fetching and parsing (via CORS proxy)
- NLP: keyword extraction, sentiment analysis, article clustering, auto-categorization
- Full-text search with TF-IDF ranking
- Reactive UI with signals, Redux store, virtual DOM, DOM reconciliation
- WebGPU-accelerated blur and shadow effects on every card
- List virtualization (only ~8 of 40+ cards in DOM at once)
- Keyboard navigation, filters, sorting, OPML import/export
- Dark theme, settings persistence, article expansion animations

---

## Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Language | Swift | 6.4-dev (nightly-main) |
| WASM SDK | SwiftWasm | `DEVELOPMENT-SNAPSHOT-2026-03-09-a` |
| JS Interop | JavaScriptKit | 0.46.5 (patched) |
| UI Framework | LINKER | Local (40K+ LOC) |
| Build Container | Docker | `swiftlang/swift:nightly-main-jammy` |
| Binary Optimizer | wasm-opt (Binaryen) | System package |
| GPU | WebGPU | WGSL shaders |
| Testing | Puppeteer | Headless Chrome |

---

## LINKER Framework

LINKER is a custom reactive UI framework written entirely in Swift, designed from the ground up for WebAssembly. It provides everything a modern web app needs without any JavaScript framework dependency.

### Architecture (161 files, 40K+ LOC)

```
LINKER/Sources/LINKER/
├── Signals/        — Reactive primitives (MutableSignal, Computed, Effect)
├── Redux/          — Store, actions, reducers, middleware
├── DSL/            — Element/Attribute/Node types, NodeBuilder
├── Runtime/        — DOMReconciler, lifecycle hooks, reactive runtime
├── Components/     — Component system + 30+ UI components (Modal, Table, Tabs, etc.)
├── GPU/            — WebGPU blur, shadow, animation engine, WGSL shaders
├── Bridge/         — SafeJSGlobal, DOMBridge, JSClosure tracking
├── Router/         — SPA routing with signals
├── Forms/          — Form state, validation, async validators
├── Security/       — HTML sanitizer, CSRF, rate limiter, CSP, WebAuthn
├── Logger/         — Actor-based structured logging with feature filters
├── Networking/     — Resource signals, WebSocket
├── Storage/        — IndexedDB abstraction with encryption
├── Workers/        — Web Worker integration
├── Animations/     — Animation timing and interpolation
├── SSR/            — Server-side rendering support
├── WASM/           — WASM-specific utilities
└── DevTools/       — In-browser debugging panel
```

### Reactive Signal System

The core primitive is `MutableSignal<T>` — a thread-safe observable value. Signals support automatic dependency tracking:

```swift
let count = MutableSignal<Int>(0)
let doubled = Computed { count.get() * 2 }  // auto-tracks `count`
let effect = Effect { print(doubled.get()) } // re-runs when `doubled` changes
count.set(5) // prints "10"
```

The Redux store exposes its state through signals, so the entire UI is reactively derived from the store.

### DOM Reconciler

LINKER uses a virtual DOM approach: Swift code builds a tree of `Element`/`Text` nodes, then `DOMReconciler` computes the minimal diff and patches the live DOM. Key features:

- **Lifecycle preservation**: Never uses innerHTML fallback when WebGPU canvases are mounted — patches in-place to preserve GPU contexts
- **Deep-patching**: Recursively walks DOM subtrees containing lifecycle-marked elements
- **Focus restoration**: Saves and restores input focus/cursor position across patches
- **Canvas-aware**: Elements marked with `data-linker-lifecycle` are protected during reconciliation

### List Virtualization

For 40+ article cards (each with ~20 child nodes + 2 GPU canvases), rendering all of them is prohibitive. The virtualizer:

1. Tracks `window.scrollY` via a throttled scroll listener (rAF + 170px threshold)
2. Computes which cards fall in the visible range (viewport height + 5-card buffer)
3. Renders only those ~8 cards, with spacer `<div>`s above and below to maintain scroll height
4. On keyboard j/k navigation, pre-computes the target scroll position and forces a re-render before calling `scrollIntoView`

Result: 5x reduction in DOM nodes, VDOM construction, and active GPU canvases.

---

## Swift-to-WASM Compilation

### The Toolchain

Swift doesn't natively target WebAssembly. The build requires:

1. **Swift 6.4-dev nightly compiler** — the host compiler running in Docker
2. **SwiftWasm SDK** (March 9, 2026 snapshot) — cross-compilation SDK targeting `wasm32-unknown-wasip1`
3. **Version matching is critical** — the SDK and compiler must share the same major version. March 1 SDK = 6.3, March 9 SDK = 6.4.

### Docker Build

The entire build happens in a Docker container for reproducibility:

```dockerfile
FROM swiftlang/swift:nightly-main-jammy@sha256:017a2b944e728ac...

# Install WASM SDK
RUN swift sdk install \
    https://download.swift.org/.../swift-DEVELOPMENT-SNAPSHOT-2026-03-09-a_wasm.artifactbundle.tar.gz \
    --checksum 37defbeca856ab15377411c3c47881132ec03f614f036223feef6b0280ce0a54

# Install optimization tools
RUN apt-get update && apt-get install -y --no-install-recommends wabt binaryen

# Resolve, patch, build
RUN WASM_BUILD=1 swift package resolve --swift-sdk swift-DEVELOPMENT-SNAPSHOT-2026-03-09-a_wasm
# ... patches applied here (see next section) ...
RUN WASM_BUILD=1 swift build --swift-sdk swift-DEVELOPMENT-SNAPSHOT-2026-03-09-a_wasm \
    --configuration release \
    -Xswiftc -Osize \
    -Xswiftc -suppress-warnings

# Optimize binary
RUN wasm-opt -Oz --strip-debug --strip-producers BulletinBoard.wasm -o BulletinBoard.wasm.opt
```

Build command from the host:
```bash
cd ~/Documents/own  # parent dir containing both LINKER/ and Bulletin-Board/
docker build -f Dockerfile.bulletin-board -t bulletin-board-wasm .
docker cp $(docker create bulletin-board-wasm):/output/BulletinBoard.wasm ./Bulletin-Board/Public/
```

### Command ABI vs Reactor ABI

WASM supports two entry point conventions:

- **Reactor ABI** (`-mexec-model=reactor`): exports `_initialize` only. The JS side must call `swift.main()` — but on JavaScriptKit this **silently no-ops** because `__main_argc_argv` isn't exported.
- **Command ABI** (default, no flag): exports `_start` which calls `_initialize` + `__main_argc_argv` automatically. JS catches the expected `UnsafeEventLoopYield` exception from `_start`.

Bulletin Board uses **Command ABI**. The JS loader calls `wasmInstance.exports._start()` and catches `UnsafeEventLoopYield`.

### The `WASM_BUILD=1` Environment Variable

Swift Package Manager evaluates `Package.swift` on the **host** (macOS/Linux), not the target (WASM). So `#if arch(wasm32)` in Package.swift always evaluates `false`. To conditionally enable WASM-specific settings, the Dockerfile sets `WASM_BUILD=1` as an environment variable that Package.swift can check with `ProcessInfo`.

---

## JavaScriptKit Patching

JavaScriptKit 0.46.5 has two bugs that prevent Swift concurrency from working on WASM. Both are patched during the Docker build.

### Bug 1: `@available` Annotations on ExecutorFactory

JavaScriptKit decorates its `MainExecutor`, `TaskExecutor`, and `SchedulingExecutor` conformances with `@available(macOS 14.0, ...)`. On WASM there is no OS versioning — these availability checks fail at runtime, so the executor protocol conformances are never visible.

**Fix**: A patched `JavaScriptEventLoop+ExecutorFactory.swift` file in `patches/` strips all `@available` annotations while preserving the implementation:

```swift
// No @available here — WASM has no OS versioning
@_spi(ExperimentalCustomExecutors)
extension JavaScriptEventLoop: MainExecutor {
    public func run() throws { swjs_unsafe_event_loop_yield() }
    public func stop() {}
}

extension JavaScriptEventLoop: TaskExecutor {}

@_spi(ExperimentalCustomExecutors)
extension JavaScriptEventLoop: SchedulingExecutor { ... }

@_spi(ExperimentalCustomExecutors)
extension JavaScriptEventLoop: ExecutorFactory {
    final class CurrentThread: TaskExecutor, SchedulingExecutor, MainExecutor, SerialExecutor { ... }
    public static var mainExecutor: any MainExecutor { CurrentThread() }
    public static var defaultExecutor: any TaskExecutor { CurrentThread() }
}
```

Applied with: `cp patches/JavaScriptEventLoop+ExecutorFactory.swift .build/checkouts/JavaScriptKit/Sources/...`

### Bug 2: `if #available(macOS 9999, ...)` Guard

In `JavaScriptEventLoop.swift`, the `installGlobalExecutorIsolated()` method wraps the `_createExecutors(factory:)` call in:

```swift
if #available(macOS 9999, iOS 9999, ...) {
    _Concurrency._createExecutors(factory: JavaScriptEventLoop.self)
}
```

This availability check is **impossible to satisfy on any OS** — it requires macOS 9999+. On native macOS the `#else` branch installs a legacy hook, but on WASM with Swift 6.4-dev (`compiler(>=6.3)`), the legacy branch is skipped. Result: **neither executor mechanism gets installed** and `Task {}` bodies never run.

**Fix**: `sed` commands in the Dockerfile remove the `@available` decorators and the `if #available(macOS 9999)` guard:

```bash
sed -i '/@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0/d' $FILE
sed -i '/@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0/d' $FILE
sed -i '/if #available(macOS 9999/d' $FILE
awk '/_createExecutors/{found=1} found && /^        \}$/{found=0; next} {print}' $FILE > tmp && mv tmp $FILE
```

### Why This Matters (Root Cause)

The original WASM concurrency bug was a **GOT (Global Offset Table) symbol duplication** issue. WASM static linking creates two copies of `swift_task_enqueueGlobal_hook` — JavaScriptKit writes one copy, the Swift runtime reads the other. The hooks never connect. Swift 6.3's `ExecutorFactory` API (`_Concurrency._createExecutors(factory:)`) bypasses hooks entirely, but JavaScriptKit's `@available` gates and impossible-to-satisfy `#available` checks block it on WASM. The two patches remove those gates.

---

## The JavaScript Loader

`BulletinBoard.js` (1,078 lines) is a self-contained JavaScript module that:

1. **Embeds the JavaScriptKit SwiftRuntime** (v708) — handles Swift/JS value marshalling, object reference counting, closure bridging, and memory management
2. **Implements WASI** (`wasi_snapshot_preview1`) — the subset Swift's stdlib needs:
   - `fd_write`: stdout/stderr output (writes byte count, not JS string length)
   - `fd_fdstat_get`, `fd_fdstat_set_flags`: file descriptor metadata stubs
   - `clock_time_get`, `clock_res_get`: nanosecond-precision timing via `performance.now()`
   - `random_get`: fills buffer via `crypto.getRandomValues()`
   - All other fd operations return `EBADF` or `ENOSYS`
3. **Implements BridgeJS** — stack-based ABI for string, number, and pointer passing between Swift and JS
4. **Loads and starts the WASM module**:
   ```javascript
   const { instance } = await WebAssembly.instantiateStreaming(
       fetch('BulletinBoard.wasm'),
       importObject  // javascript_kit + bjs + wasi_snapshot_preview1
   );
   instance.exports._start();  // Command ABI entry point
   // Catches UnsafeEventLoopYield — expected from event loop yield
   ```

The import object wires three namespaces:
- `javascript_kit`: ~40 functions for JS object manipulation (create, get/set property, call function, etc.)
- `bjs`: BridgeJS stack operations for typed value passing
- `wasi_snapshot_preview1`: POSIX-like system call shims

### Key `fd_write` Detail

A subtle WASI bug: `fd_write` must write the **total bytes written** (from `TextEncoder`) to the `nwritten` pointer, not the JavaScript string length. UTF-8 multi-byte characters make these different.

---

## WASM Binary Size Optimization

The raw compiled binary is ~69 MB. After optimization: **48 MB**.

### Optimization Pipeline

| Step | Flag/Tool | Effect |
|------|-----------|--------|
| Swift `-Osize` | `-Xswiftc -Osize` | Optimize for size over speed |
| wasm-opt `-Oz` | `wasm-opt -Oz` | Binaryen's aggressive size optimization |
| Strip debug info | `--strip-debug` | Remove DWARF debug sections |
| Strip producers | `--strip-producers` | Remove producer metadata |
| Suppress warnings | `-Xswiftc -suppress-warnings` | No effect on size, cleaner logs |

```bash
# Before: 69 MB (54 MB in some builds)
wasm-opt -Oz --strip-debug --strip-producers BulletinBoard.wasm -o BulletinBoard.wasm.opt
# After: 48 MB
```

### Why It's Still 48 MB

Swift's WASM binary includes:
- The entire Swift standard library (statically linked)
- Foundation framework subset
- JavaScriptKit runtime
- LINKER framework (40K+ LOC)
- The application code itself
- String metadata, type reflection data, protocol witness tables

There is no tree-shaking for Swift WASM yet — unused stdlib functions are included. The Swift WASM team is working on dead code stripping, but as of March 2026 it's not available.

### Service Worker Mitigation

Since 48 MB is large for a web download, a service worker with **stale-while-revalidate** caching ensures:
- First load: full 48 MB download (but streaming compilation starts immediately)
- Subsequent loads: served from cache in <100ms, background refresh
- `WebAssembly.instantiateStreaming()` compiles while downloading — the 48 MB doesn't mean 48 MB of wait time

---

## WebGPU Integration

Every article card has two GPU-accelerated canvases:
- **Blur canvas**: Frosted-glass background effect (procedural, no texture capture)
- **Shadow canvas**: Elevation-based soft shadow with optional mouse reactivity

### Architecture

```
LINKER/GPU/
├── GPUEffectManager.swift        — Central coordinator, IntersectionObserver for visibility
├── GPUProceduralBlurEffect.swift — Procedural blur with tint color from article's dominant color
├── GPUShadowEffect.swift         — Soft shadow with mouse-reactive elevation
├── GPUAnimationEngine.swift      — requestAnimationFrame-based render loop
├── WebGPUBridge.swift            — Low-level WebGPU API bindings (adapter, device, pipeline)
├── GPUShaders.swift              — WGSL fragment/vertex shaders for blur
└── GPUShadowShaders.swift        — WGSL shaders for shadow
```

### Lifecycle

1. `DOMReconciler` patches the DOM, inserting `<canvas data-linker-lifecycle="true">` elements
2. `LifecycleRegistry` fires `onMount` hooks after DOM insertion
3. `onMount` uses double-`requestAnimationFrame` to wait for layout, then reads `getBoundingClientRect`
4. `GPUEffectManager.registerBlur/registerShadow` creates WebGPU pipeline, bind groups, uniform buffers
5. `IntersectionObserver` pauses rendering when canvas scrolls off-screen
6. When virtualization removes a card from DOM, `onUnmount` fires and cleans up the GPU resources

### Canvas Preservation

The DOMReconciler has special logic to never destroy mounted canvases during DOM patching:
- When >60% of nodes change, normal reconcilers use `innerHTML` — LINKER skips this if lifecycle elements exist
- Deep-patching recurses into subtrees, updating text and attributes while preserving `<canvas>` children
- Nested lifecycle elements (e.g., blur canvas inside shadow canvas wrapper) are handled recursively

---

## Service Worker & Caching

`sw.js` implements a **stale-while-revalidate** strategy:

```
Request → Cache hit?
  ├── Yes → Return cached immediately, fetch fresh copy in background
  └── No  → Fetch from network, cache the response, return it
```

- **Pre-cached on install**: `index.html`, `styles.css`, `BulletinBoard.js`, `BulletinBoard.wasm`
- **Cache name**: `bulletin-board-v2` (old caches deleted on activate)
- **`skipWaiting()` + `clients.claim()`**: New service worker activates immediately

This makes the 48 MB WASM binary a one-time download cost.

---

## Local Development

### Prerequisites

- Docker (for WASM builds)
- Python 3 (for local server)
- Node.js + Puppeteer (for testing)

### Build & Test

```bash
# 1. Build WASM (from parent directory)
cd ~/Documents/own
docker build -f Dockerfile.bulletin-board -t bulletin-board-wasm .

# 2. Extract binary
cd Bulletin-Board
docker cp $(docker create bulletin-board-wasm):/output/BulletinBoard.wasm ./Public/

# 3. Serve locally (custom headers for WebGPU)
python3 serve.py
# → http://localhost:8080

# 4. Run Puppeteer tests
node test-virtualization.js
```

### serve.py

The local server adds required headers for WebGPU (SharedArrayBuffer):

```python
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: credentialless  # allows cross-origin RSS fetches
```

Using `credentialless` instead of `require-corp` so the CORS proxy for RSS feeds works without remote servers setting CORP headers.

---

## Deployment

The project uses two branches:

- **`main`**: Swift source code, Dockerfile, patches, test files
- **`gh-pages`**: Compiled assets for GitHub Pages (`index.html`, `styles.css`, `BulletinBoard.js`, `BulletinBoard.wasm`, `sw.js`)

Deploy workflow:
```bash
# Build and extract
docker build -f Dockerfile.bulletin-board -t bulletin-board-wasm .
docker cp $(docker create bulletin-board-wasm):/output/BulletinBoard.wasm ./Bulletin-Board/Public/

# Push source
cd Bulletin-Board && git add -A && git commit -m "feat: ..." && git push origin main

# Deploy to gh-pages
git checkout gh-pages
cp Public/* .
git add -A && git commit -m "deploy: ..." && git push origin gh-pages
git checkout main
```

---

## Key Lessons Learned

### WASM Compilation

1. **Foundation APIs don't exist in WASM**: `Timer`, `XMLParser`, `URLSession`, `NSPredicate` — all unavailable. Use `Task.sleep`, manual XML parsing, JS `fetch`, and `NSRegularExpression` instead.
2. **GOT symbol duplication**: WASM static linking creates duplicate `swift_task_enqueueGlobal_hook` symbols. Legacy hooks are broken — use the `ExecutorFactory` API (Swift 6.3+).
3. **SDK version matching**: The WASM SDK and host compiler must share the same major version. A March 1 SDK is 6.3, March 9 is 6.4.
4. **`@available` is meaningless on WASM**: There's no OS versioning. Any `@available` gate effectively disables the code.
5. **Command ABI, not Reactor**: Reactor ABI exports `_initialize` only — `swift.main()` silently no-ops. Command ABI exports `_start` which calls both.
6. **`if #available(macOS 9999)` kills the executor**: This is an impossible-to-satisfy check. On WASM it always fails, and with `compiler(>=6.3)` the fallback path is skipped too. Both code paths are dead.

### JavaScript Interop

7. **`this`-binding**: `obj.method.function?()` loses `this`. Use `obj.method!()` to preserve it.
8. **`JSPromise` needs JavaScriptEventLoop**: The async `.value` property is defined in JavaScriptEventLoop, not JavaScriptKit core.
9. **Dynamic member lookup differs on WASM**: `obj.method!(args)` requires `!` for direct calls, but `obj.prop.method(args)` must NOT use `!` for chained access.
10. **`fd_write` bytes vs characters**: Write the UTF-8 byte count to `nwritten`, not the JavaScript string length.

### DOM & Rendering

11. **`innerHTML` destroys GPU canvases**: When the reconciler falls back to innerHTML, all WebGPU contexts are lost. Skip the fallback when lifecycle elements are mounted.
12. **Canvas sizing needs double-rAF**: `requestAnimationFrame` fires before browser layout. For reliable `getBoundingClientRect`, nest two rAFs.
13. **`event.target` may be a text node**: Always use `target.closest("[data-action]")` for event delegation.
14. **Re-rendering destroys focus**: Skip no-op renders by comparing HTML strings; use `queueMicrotask` batching.

### Build & Deploy

15. **Docker nightly tags float**: `swiftlang/swift:nightly-main-jammy` updates silently. Pin with `@sha256:...` for reproducibility.
16. **No Python in Swift Docker image**: Use `sed`/`awk` for patching, not Python scripts.
17. **`docker system prune -af`**: Run before large builds to reclaim disk space.
18. **Streaming compilation**: `WebAssembly.instantiateStreaming()` compiles while downloading — the 48 MB binary loads faster than you'd expect.

---

## Project Statistics

| Metric | Value |
|--------|-------|
| Bulletin Board Swift LOC | ~7,000 |
| LINKER Framework Swift LOC | ~40,000 |
| Total Swift LOC | ~47,000 |
| WASM Binary (optimized) | 48 MB |
| WASM Binary (unoptimized) | 69 MB |
| Public Assets | 5 files |
| GPU Canvases per Card | 2 (blur + shadow) |
| Cards Virtualized | ~8 visible of 40+ total |
| Build Time (Docker) | ~4 minutes |
| WASM Compile + Instantiate | ~90ms |
| First Render | <150ms from script start |
