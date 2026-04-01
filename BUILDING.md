# Building a Swift WASM Web Application with LINKER

Complete guide to compiling Swift source code into a WebAssembly application that runs in the browser. Covers the entire pipeline from Swift files to a deployed website, including the Docker build environment, JavaScriptKit patching, the JavaScript loader, WASI shim, and GitHub Pages deployment.

This guide uses Bulletin Board as the reference project but applies to any LINKER-based application.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Directory Layout](#directory-layout)
4. [Package.swift Configuration](#packageswift-configuration)
5. [Swift Entry Point](#swift-entry-point)
6. [The Docker Build Environment](#the-docker-build-environment)
7. [JavaScriptKit Patches](#javascriptkit-patches)
8. [The Build Command](#the-build-command)
9. [WASM Optimization](#wasm-optimization)
10. [The JavaScript Loader (BulletinBoard.js)](#the-javascript-loader)
11. [The HTML Shell (index.html)](#the-html-shell)
12. [The CSS (styles.css)](#the-css)
13. [Local Development Server](#local-development-server)
14. [Deploying to GitHub Pages](#deploying-to-github-pages)
15. [Creating a New LINKER Project from Scratch](#creating-a-new-linker-project-from-scratch)
16. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Browser                               │
│                                                              │
│  index.html ──loads──► BulletinBoard.js ──loads──► .wasm    │
│                              │                       │       │
│                    ┌─────────┴────────┐              │       │
│                    │  JS Runtime      │              │       │
│                    │  ┌─────────────┐ │   ┌─────────┴─────┐ │
│                    │  │SwiftRuntime │◄├───┤ Swift code    │ │
│                    │  │(JSKit v708) │ │   │ (compiled to  │ │
│                    │  ├─────────────┤ │   │  WASM)        │ │
│                    │  │BridgeJS ABI │ │   │               │ │
│                    │  ├─────────────┤ │   │ LINKER        │ │
│                    │  │WASI shim    │ │   │ framework     │ │
│                    │  └─────────────┘ │   └───────────────┘ │
│                    └──────────────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

The pipeline:

1. **Swift source files** → compiled to **WebAssembly** binary via Swift WASM SDK inside Docker
2. **BulletinBoard.js** → hand-written JavaScript loader that contains:
   - JavaScriptKit SwiftRuntime (Swift↔JS interop bridge)
   - BridgeJS stack-based ABI (value passing between Swift and JS)
   - WASI shim (filesystem/clock/random syscall stubs for browser)
   - WASM loader with download progress tracking
3. **index.html** → minimal HTML shell that loads the JS module
4. **styles.css** → all application styles

The WASM binary contains your entire Swift application (including LINKER framework) compiled to WebAssembly. The JS loader provides the browser APIs that WASM code calls through JavaScriptKit.

---

## Prerequisites

| Requirement | Version | Purpose |
|------------|---------|---------|
| Docker | Any recent | Build environment |
| Git | Any | Version control |
| macOS/Linux host | Any | Running Docker |
| ~6GB disk | - | Docker image + build cache |

No Swift installation is needed on the host — everything compiles inside Docker.

### Exact versions used in the Docker image

| Component | Version | Notes |
|-----------|---------|-------|
| Docker base image | `swiftlang/swift:nightly-main-jammy` | Ubuntu 22.04 (Jammy) |
| Docker image digest | `sha256:017a2b944e728ac4e15cac89ff0834a8655dbdf2817e3c038c6c284416a4244b` | Pin for reproducibility |
| Swift compiler | 6.4-dev (nightly-main) | Must match WASM SDK major version |
| Swift WASM SDK | `swift-DEVELOPMENT-SNAPSHOT-2026-03-09-a_wasm` | March 9, 2026 snapshot (6.4-compatible) |
| WASM SDK checksum | `37defbeca856ab15377411c3c47881132ec03f614f036223feef6b0280ce0a54` | Verified on install |
| Ubuntu packages | `wabt`, `binaryen` | `wasm-objdump` and `wasm-opt` tools |
| JavaScriptKit | 0.46.5 (revision `5529520b`) | Swift↔JS interop, **requires 2 patches** |
| swift-syntax | 602.0.0 | Transitive dependency of JavaScriptKit |
| LINKER | Local path (`../LINKER`) | Reactive UI framework |

---

## Directory Layout

The build expects this directory structure:

```
parent-directory/
├── LINKER/                          # LINKER framework (git repo)
│   ├── Package.swift
│   └── Sources/LINKER/
│
├── Bulletin-Board/                  # Your app (git repo)
│   ├── Package.swift
│   ├── Package.resolved
│   ├── .dockerignore
│   ├── patches/
│   │   └── JavaScriptEventLoop+ExecutorFactory.swift
│   ├── Sources/BulletinBoard/
│   │   ├── main.swift               # Entry point
│   │   ├── Components/
│   │   ├── Models/
│   │   ├── Services/
│   │   ├── State/
│   │   └── Security/
│   ├── Tests/BulletinBoardTests/
│   └── Public/
│       ├── index.html
│       ├── styles.css
│       ├── BulletinBoard.js          # JS loader (hand-written)
│       └── BulletinBoard.wasm        # Output from Docker build
│
└── Dockerfile.bulletin-board         # Build Dockerfile (lives in parent)
```

The Dockerfile sits in the **parent** directory because it needs to `COPY` both `LINKER/` and `Bulletin-Board/` into the build context.

### .dockerignore

Place in your app directory to exclude unnecessary files from the Docker build context:

```
.swiftpm
.build
Bundle
dist
*.md
.git
.github
.DS_Store
```

---

## Package.swift Configuration

### App Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BulletinBoard",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(
            name: "BulletinBoard",
            targets: ["BulletinBoard"]
        )
    ],
    dependencies: [
        .package(path: "../LINKER"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.46.0")
    ],
    targets: [
        .executableTarget(
            name: "BulletinBoard",
            dependencies: [
                .product(name: "LINKER", package: "LINKER"),
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit")
            ]
        ),
        .testTarget(
            name: "BulletinBoardTests",
            dependencies: [
                "BulletinBoard",
                .product(name: "LINKER", package: "LINKER"),
                .product(name: "LINKERTesting", package: "LINKER")
            ]
        )
    ]
)
```

Key points:
- `swift-tools-version: 6.0` — required for Swift 6 concurrency
- `.executable` product — produces a binary (not library), which exports `_start` in WASM
- `JavaScriptEventLoop` dependency — provides the async/await executor for WASM
- `LINKER` is a **local path** dependency (`../LINKER`), resolved relative to the Dockerfile's workspace

### LINKER Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let jsKit: [Target.Dependency] = [
    .product(name: "JavaScriptKit", package: "JavaScriptKit"),
    .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
]

let package = Package(
    name: "LINKER",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "LINKER", targets: ["LINKER"]),
        .library(name: "LINKERTesting", targets: ["LINKERTesting"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.46.0")
    ],
    targets: [
        .target(name: "LINKER", dependencies: jsKit, path: "Sources/LINKER"),
        .target(name: "LINKERTesting", dependencies: ["LINKER"], path: "Sources/LINKERTesting"),
        .testTarget(name: "LINKERTests", dependencies: ["LINKER", "LINKERTesting"], path: "Tests/LINKERTests", exclude: ["Disabled"])
    ]
)
```

Both packages share the same JavaScriptKit dependency. SwiftPM deduplicates it automatically.

---

## Swift Entry Point

The app entry point (`main.swift`) must:

1. Guard all WASM code with `#if canImport(JavaScriptKit) && arch(wasm32)`
2. Install the JavaScriptEventLoop executor
3. Launch the app in a `Task` (async context)

```swift
import Foundation
import LINKER

#if canImport(JavaScriptKit) && arch(wasm32)
import JavaScriptKit
import JavaScriptEventLoop

JavaScriptEventLoop.installGlobalExecutor()

print("[swift] My App - Starting")

Task {
    await App.main()
}

#else
print("My App - Native mode (no WASM)")
#endif
```

Why `arch(wasm32)`:
- `canImport(JavaScriptKit)` alone isn't sufficient — it resolves to `true` during native `swift test` since JavaScriptKit is a dependency
- `arch(wasm32)` is a compile-time check that is `true` only when targeting WebAssembly
- The `#else` branch allows the executable to compile and run natively for testing

Why `installGlobalExecutor()`:
- This registers the JavaScriptEventLoop as the Swift concurrency executor
- Without it, `Task {}` bodies are enqueued but never executed
- Uses the ExecutorFactory API (Swift 6.3+) which bypasses the broken GOT hook mechanism

Why `Task { await App.main() }`:
- Swift WASM uses Command ABI — `_start` is called synchronously by the JS loader
- `installGlobalExecutor()` makes the event loop throw `UnsafeEventLoopYield` after setup
- The JS loader catches this exception and control returns to the browser event loop
- The `Task` body runs later via JavaScript's microtask queue

---

## The Docker Build Environment

### Dockerfile

```dockerfile
# Swift main nightly (6.4-dev) — has ExecutorFactory API (bypasses broken GOT hooks)
FROM swiftlang/swift:nightly-main-jammy@sha256:017a2b944e728ac4e15cac89ff0834a8655dbdf2817e3c038c6c284416a4244b

# Install Swift WASM SDK (main branch snapshot, March 9 — 6.4 compatible)
RUN swift sdk install \
    https://download.swift.org/development/wasm-sdk/swift-DEVELOPMENT-SNAPSHOT-2026-03-09-a/swift-DEVELOPMENT-SNAPSHOT-2026-03-09-a_wasm.artifactbundle.tar.gz \
    --checksum 37defbeca856ab15377411c3c47881132ec03f614f036223feef6b0280ce0a54

# Install WASM optimization tools
RUN apt-get update && apt-get install -y --no-install-recommends wabt binaryen && \
    rm -rf /var/lib/apt/lists/*

# Verify SDK installation
RUN swift sdk list

# Set working directory
WORKDIR /workspace

# Copy LINKER framework
COPY LINKER /workspace/LINKER

# Copy project
COPY Bulletin-Board /workspace/Bulletin-Board

# Resolve dependencies first
WORKDIR /workspace/Bulletin-Board
RUN WASM_BUILD=1 swift package resolve --swift-sdk swift-DEVELOPMENT-SNAPSHOT-2026-03-09-a_wasm

# Patch JavaScriptKit for Swift 6.4-dev WASM compatibility
# 1. ExecutorFactory: remove @available annotations (WASM has no OS versioning)
RUN cp patches/JavaScriptEventLoop+ExecutorFactory.swift \
    .build/checkouts/JavaScriptKit/Sources/JavaScriptEventLoop/JavaScriptEventLoop+ExecutorFactory.swift && \
    echo "=== Patched ExecutorFactory ==="

# 2. JavaScriptEventLoop.swift: remove `if #available(macOS 9999, ...)` guard around
#    _createExecutors — on WASM this availability check always fails, so the executor
#    factory never gets installed and Task bodies never run.
#    Also remove @available on the class and JSPromise extension declarations.
RUN FILE=.build/checkouts/JavaScriptKit/Sources/JavaScriptEventLoop/JavaScriptEventLoop.swift && \
    sed -i '/@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0/d' $FILE && \
    sed -i '/@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0/d' $FILE && \
    sed -i '/if #available(macOS 9999/d' $FILE && \
    awk '/_createExecutors/{found=1} found && /^        \}$/{found=0; next} {print}' $FILE > ${FILE}.tmp && \
    mv ${FILE}.tmp $FILE && \
    echo "=== Patched JavaScriptEventLoop.swift ===" && \
    sed -n '/installGlobalExecutorIsolated/,/^    }/p' $FILE

# Build WASM binary (Command ABI — _start calls _initialize + main automatically)
RUN WASM_BUILD=1 swift build --swift-sdk swift-DEVELOPMENT-SNAPSHOT-2026-03-09-a_wasm \
    --configuration release \
    -Xswiftc -O \
    -Xswiftc -whole-module-optimization \
    -Xswiftc -suppress-warnings \
    -Xlinker --gc-sections \
    -Xlinker --strip-all

# Find WASM binary, optimize with wasm-opt, copy to output
RUN mkdir -p /output && \
    WASM_FILE=$(find .build -name "BulletinBoard.wasm" -print -quit) && \
    echo "Found WASM at: $WASM_FILE" && \
    echo "Before wasm-opt:" && ls -lh "$WASM_FILE" && \
    wasm-opt -Oz --strip-debug --strip-producers --converge --vacuum --remove-unused-names \
        --remove-unused-module-elements "$WASM_FILE" -o "$WASM_FILE.opt" && \
    mv "$WASM_FILE.opt" "$WASM_FILE" && \
    echo "After wasm-opt:" && ls -lh "$WASM_FILE" && \
    echo "Exports:" && wasm-objdump -j Export -x "$WASM_FILE" && \
    cp "$WASM_FILE" /output/BulletinBoard.wasm && \
    echo "Output:" && ls -lh /output/BulletinBoard.wasm

CMD ["echo", "Build complete. Extract /output/BulletinBoard.wasm"]
```

### Build sequence explanation

| Step | What happens | Why |
|------|-------------|-----|
| `FROM swiftlang/swift:nightly-main-jammy` | Pull Swift 6.4-dev compiler on Ubuntu 22.04 | Need nightly for ExecutorFactory API |
| `swift sdk install` | Download and register the WASM cross-compilation SDK | Separate from the host compiler — provides WASM stdlib, Foundation, etc. |
| `apt-get install wabt binaryen` | Install `wasm-objdump` (inspect exports) and `wasm-opt` (shrink binary) | Post-build optimization |
| `COPY LINKER` + `COPY Bulletin-Board` | Both repos enter Docker context | LINKER is a local path dependency |
| `swift package resolve --swift-sdk ...` | Download JavaScriptKit and resolve dependency graph | Must specify `--swift-sdk` so WASM-specific resolution works |
| `WASM_BUILD=1` env var | Signals to Package.swift that we're building for WASM | `#if arch(wasm32)` evaluates on the **host** (always false); env var is the workaround |
| Patch JavaScriptKit (2 steps) | Fix WASM executor installation | See [JavaScriptKit Patches](#javascriptkit-patches) below |
| `swift build --swift-sdk ... --configuration release` | Cross-compile all Swift to WASM | Produces a `.wasm` binary in `.build/` |
| `wasm-opt -Oz` | Dead code elimination, function merging, size optimization | Reduces binary (~7MB Foundation-free) |
| `cp` to `/output/` | Place final binary for extraction | `docker cp` pulls it out |

### Running the build

```bash
# From the parent directory containing both LINKER/ and Bulletin-Board/
cd /path/to/parent
docker build -f Dockerfile.bulletin-board -t my-app-wasm .

# Extract the compiled binary
docker cp $(docker create my-app-wasm):/output/BulletinBoard.wasm Bulletin-Board/Public/
```

Build time: ~3-5 minutes (first build longer due to dependency download).

---

## JavaScriptKit Patches

JavaScriptKit 0.46.5 has two bugs that prevent WASM executor installation. Both must be patched.

### Background: the GOT hook problem

Swift's legacy concurrency uses a global function pointer `swift_task_enqueueGlobal_hook`. JavaScriptKit writes to this hook to redirect task execution to the browser event loop. However, WASM static linking creates **two copies** of this symbol (one in JavaScriptKit, one in Swift runtime). JavaScriptKit writes one copy, Swift reads the other — hooks never fire, and `Task {}` bodies silently never execute.

Swift 6.3+ introduced the **ExecutorFactory** API as the replacement. Instead of hooking global function pointers, you implement `ExecutorFactory` protocol conformances and register them via `_Concurrency._createExecutors(factory:)`. This works correctly with WASM static linking.

### Patch 1: ExecutorFactory (remove @available)

**File**: `patches/JavaScriptEventLoop+ExecutorFactory.swift`
**Replaces**: `.build/checkouts/JavaScriptKit/Sources/JavaScriptEventLoop/JavaScriptEventLoop+ExecutorFactory.swift`

The original file wraps all ExecutorFactory conformances in `@available(macOS 14.0, iOS 17.0, ...)`. On WASM, OS version checks always fail because there is no operating system. This causes `asSchedulingExecutor` to return nil and executor registration to silently fail.

The patch removes all `@available` annotations while keeping the implementation identical:

```swift
#if compiler(>=6.3)
@_spi(ExperimentalCustomExecutors) import _Concurrency
#else
import _Concurrency
#endif
import _CJavaScriptKit

#if compiler(>=6.3)

@_spi(ExperimentalCustomExecutors)
extension JavaScriptEventLoop: MainExecutor {
    public func run() throws {
        swjs_unsafe_event_loop_yield()
    }
    public func stop() {}
}

extension JavaScriptEventLoop: TaskExecutor {}

@_spi(ExperimentalCustomExecutors)
extension JavaScriptEventLoop: SchedulingExecutor {
    public func enqueue<C: Clock>(
        _ job: consuming ExecutorJob,
        after delay: C.Duration,
        tolerance: C.Duration?,
        clock: C
    ) {
        let duration: Duration
        if let _ = clock as? ContinuousClock {
            duration = delay as! ContinuousClock.Duration
        } else if let _ = clock as? SuspendingClock {
            duration = delay as! SuspendingClock.Duration
        } else {
            let unowned = UnownedJob(job)
            JavaScriptEventLoop.shared.enqueue(unowned)
            return
        }
        let (seconds, attoseconds) = duration.components
        let milliseconds = Double(seconds) * 1_000 + (Double(attoseconds) / 1_000_000_000_000_000)
        self.enqueue(UnownedJob(job), withDelay: milliseconds)
    }
}

@_spi(ExperimentalCustomExecutors)
extension JavaScriptEventLoop: ExecutorFactory {
    final class CurrentThread: TaskExecutor, SchedulingExecutor, MainExecutor, SerialExecutor {
        func checkIsolated() {}
        func enqueue(_ job: consuming ExecutorJob) {
            JavaScriptEventLoop.shared.enqueue(job)
        }
        func enqueue<C: Clock>(
            _ job: consuming ExecutorJob,
            after delay: C.Duration,
            tolerance: C.Duration?,
            clock: C
        ) {
            JavaScriptEventLoop.shared.enqueue(job, after: delay, tolerance: tolerance, clock: clock)
        }
        func run() throws { try JavaScriptEventLoop.shared.run() }
        func stop() { JavaScriptEventLoop.shared.stop() }
    }

    public static var mainExecutor: any MainExecutor { CurrentThread() }
    public static var defaultExecutor: any TaskExecutor { CurrentThread() }
}

#endif
```

### Patch 2: installGlobalExecutor (remove impossible availability guard)

**Applied via sed/awk in Dockerfile** to `.build/checkouts/JavaScriptKit/Sources/JavaScriptEventLoop/JavaScriptEventLoop.swift`

The `installGlobalExecutorIsolated()` method wraps its `_createExecutors(factory:)` call inside:
```swift
if #available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, visionOS 9999, *) {
    _Concurrency._createExecutors(factory: JavaScriptEventLoop.self)
}
```

This availability check is **impossible to satisfy** on any OS — it requires macOS 9999. On native macOS, Swift falls through to a `#else` block with legacy hooks. But on WASM:
- `#available(macOS 9999, ...)` always evaluates to `false`
- `compiler(>=6.3)` is `true`, so the `#else` legacy path is skipped
- **Neither code path executes** — no executor gets installed

The Dockerfile sed commands:
```bash
# Remove @available decorations on class/extension declarations
sed -i '/@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0/d' $FILE
sed -i '/@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0/d' $FILE

# Remove the impossible availability guard line
sed -i '/if #available(macOS 9999/d' $FILE

# Remove the closing brace of the guard block
awk '/_createExecutors/{found=1} found && /^        \}$/{found=0; next} {print}' $FILE > ${FILE}.tmp
mv ${FILE}.tmp $FILE
```

After patching, `_createExecutors(factory: JavaScriptEventLoop.self)` executes unconditionally.

---

## The Build Command

```bash
WASM_BUILD=1 swift build \
    --swift-sdk swift-DEVELOPMENT-SNAPSHOT-2026-03-09-a_wasm \
    --configuration release \
    -Xswiftc -O \
    -Xswiftc -whole-module-optimization \
    -Xswiftc -suppress-warnings \
    -Xlinker --gc-sections \
    -Xlinker --strip-all
```

| Flag | Purpose |
|------|---------|
| `--swift-sdk ...` | Cross-compile for WASM instead of native |
| `--configuration release` | Optimized build (no debug info) |
| `-Xswiftc -O` | Optimize for speed (see note below on why not `-Osize`) |
| `-Xswiftc -whole-module-optimization` | Cross-module inlining and dead code elimination |
| `-Xswiftc -suppress-warnings` | Clean build output |
| `-Xlinker --gc-sections` | Remove unreferenced code sections during linking |
| `-Xlinker --strip-all` | Strip symbol table from binary |

### ABI: Command vs Reactor

This build uses **Command ABI** (the default — no extra flags). This means:
- The WASM binary exports `_start`
- `_start` calls `_initialize` (global constructors) and then `__main_argc_argv` (your `main.swift`)
- The JS loader calls `wasmInstance.exports._start()`

The alternative is **Reactor ABI** (`-mexec-model=reactor`), which:
- Only exports `_initialize` — does **NOT** export `main`/`__main_argc_argv`
- `swift.main()` silently no-ops
- Requires the JS loader to call `_initialize()` then `swift.main()` separately

**Use Command ABI** (default). Reactor ABI is for library-style WASM modules, not applications.

---

## WASM Optimization

After compilation, `wasm-opt` from Binaryen shrinks the binary:

```bash
wasm-opt -Oz \
    --strip-debug \
    --strip-producers \
    --converge \
    --vacuum \
    --remove-unused-names \
    --remove-unused-module-elements \
    input.wasm -o output.wasm
```

| Flag | Purpose |
|------|---------|
| `-Oz` | Aggressive size optimization (smaller than `-Os`) |
| `--strip-debug` | Remove debug sections |
| `--strip-producers` | Remove producer metadata |
| `--converge` | Repeat passes until no further reduction |
| `--vacuum` | Remove unreachable code |
| `--remove-unused-names` | Strip function/type names |
| `--remove-unused-module-elements` | Remove unused functions, globals, types |

Typical reduction: ~69MB → ~48MB (30% smaller) with Foundation; ~7MB without Foundation imports.

> **Foundation-free builds**: Bulletin Board eliminates all `import Foundation` from source
> files, which removes Foundation's standard library from the binary. This drops the final
> WASM size from ~48MB to ~7MB. Foundation is the single largest contributor to WASM binary
> size in Swift. Note: this is standard Swift WASM, not Embedded Swift (which would be even
> smaller but requires giving up existentials, String interpolation, etc.).

You can verify the exports with:
```bash
wasm-objdump -j Export -x BulletinBoard.wasm
```

Expected exports for Command ABI: `memory`, `_start`, `swjs_library_version`, `swjs_library_features`, `swjs_prepare_host_function_call`, `swjs_cleanup_host_function_call`, `swjs_call_host_function`, `swjs_free_host_function`, plus any BridgeJS exports.

---

## The JavaScript Loader

The JS file (`BulletinBoard.js`) is **hand-written** (not generated by a build tool). It contains four sections that you must provide for any LINKER-based app.

### Section 1: JavaScriptKit SwiftRuntime (~650 lines)

This is the browser-side counterpart of JavaScriptKit. It:
- Manages a reference-counted JavaScript object heap (`JSObjectSpace`)
- Provides 50+ WASM import functions for Swift↔JS interop (property access, function calls, string encoding, typed arrays, closures, BigInt, etc.)
- Handles the `UnsafeEventLoopYield` exception (thrown when Swift yields to the browser event loop)

Version: **708** (from JavaScriptKit 0.46.5 `runtime.mjs`).

To extract this for a new project, find `runtime.mjs` in the JavaScriptKit 0.46.5 source at:
```
Sources/JavaScriptKit/Runtime/runtime.mjs
```

The key classes to inline: `SwiftClosureDeallocator`, `JSObjectSpace`, `UnsafeEventLoopYield`, `SwiftRuntime`, plus helper functions (`decode`, `decodeArray`, `write`, `writeAndReturnKindBits`, `ITCInterface`, `MessageBroker`).

### Section 2: BridgeJS Runtime (~190 lines)

Stack-based ABI for passing values between Swift and JavaScript. Manages five stacks:
- `i32Stack`, `f32Stack`, `f64Stack` — numeric values
- `strStack` — string values
- `ptrStack` — pointer values

Plus string/memory operations (`swift_js_return_string`, `swift_js_init_memory`, `swift_js_make_js_string`) and optional return helpers.

Extract from JavaScriptKit 0.46.5 BridgeJS source, or copy from the existing `BulletinBoard.js`.

### Section 3: WASI Shim (~110 lines)

The WASM binary targets `wasm32-unknown-wasi` which requires WASI syscalls. Since we're running in a browser (not a WASI runtime like wasmtime), we provide stubs:

| Syscall | Implementation |
|---------|---------------|
| `fd_write` (fd 1,2) | Decode UTF-8 bytes → `console.log`/`console.error`. **Must write total byte count to `nwritten` pointer** (not JS string length) |
| `fd_fdstat_get` | Return filetype=2 (char device) for fd ≤ 2, filetype=4 otherwise |
| `fd_fdstat_set_flags` | Return 0 (success no-op) |
| `clock_time_get` | `BigInt(Date.now()) * 1000000n` (milliseconds → nanoseconds) |
| `random_get` | `crypto.getRandomValues()` |
| `args_sizes_get` / `environ_sizes_get` | Return 0 args/env |
| `proc_exit` | Throw error (should not be called in normal operation) |
| Everything else | Return EBADF (8) or ENOSYS (52) |

### Section 4: Main Loader (~120 lines)

The exported `startWasmApp()` async function:

```javascript
export async function startWasmApp() {
    // 1. Create SwiftRuntime and BridgeJS instances
    const swift = new SwiftRuntime();
    const bjsRuntime = createBJSRuntime(swift);

    // 2. Build import object with all three WASM import namespaces
    let resolvedMemory = null;
    const importObject = {
        javascript_kit: swift.wasmImports,
        bjs: bjsRuntime.imports,
        wasi_snapshot_preview1: createWASI(() => resolvedMemory),
    };

    // 3. Fetch WASM with progress tracking
    const rawResponse = await fetch('BulletinBoard.wasm');
    // ... read chunks, update progress bar ...

    // 4. Instantiate
    const wasmModule = await WebAssembly.instantiateStreaming(response, importObject);
    const instance = wasmModule.instance;

    // 5. Wire up runtimes (must happen BEFORE calling _start)
    resolvedMemory = instance.exports.memory;
    swift.setInstance(instance);
    bjsRuntime.setInstance(instance);

    // 6. Start the app (Command ABI)
    try {
        instance.exports._start();
    } catch (e) {
        if (e instanceof swift.UnsafeEventLoopYield) { /* expected */ }
        else throw e;
    }
}
```

The three WASM import namespaces must match exactly:
- `javascript_kit` — SwiftRuntime's import functions
- `bjs` — BridgeJS stack operations
- `wasi_snapshot_preview1` — WASI syscall stubs

### Download progress tracking

`WebAssembly.instantiateStreaming` doesn't expose download progress. The workaround:

1. `fetch()` the WASM file manually
2. Read `content-length` header for total size
3. Stream response body chunks via `response.body.getReader()`
4. Track `loaded` bytes, update progress bar
5. Reassemble chunks into a `Blob` → `new Response(blob)`
6. Pass the reconstructed Response to `instantiateStreaming`

This adds negligible overhead but provides a real-time download progress indicator for the ~48MB binary.

---

## The HTML Shell

Minimal `index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My App</title>

    <meta http-equiv="Content-Security-Policy" content="default-src 'self';
        script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval';
        style-src 'self' 'unsafe-inline';
        img-src 'self' data: https:;
        connect-src 'self' https:;
        font-src 'self' data:;">

    <link rel="stylesheet" href="styles.css">
    <link rel="preload" href="BulletinBoard.wasm" as="fetch" type="application/wasm" crossorigin>
</head>
<body>
    <div id="app">
        <div class="loading">
            <div class="spinner"></div>
            <p>Loading...</p>
            <div class="loading-progress">
                <div class="loading-progress__bar" id="load-progress-bar"></div>
            </div>
            <p class="loading-progress__text" id="load-progress-text"></p>
        </div>
    </div>

    <script type="module">
        import { startWasmApp } from './BulletinBoard.js'
        startWasmApp().catch(err => {
            console.error('Failed to start WASM app:', err)
            document.getElementById('app').innerHTML = `
                <div class="error-container">
                    <h1>Failed to Load</h1>
                    <p>${err.message || 'Unknown error'}</p>
                    <button onclick="location.reload()">Retry</button>
                </div>
            `
        })
    </script>
</body>
</html>
```

Key details:
- `wasm-unsafe-eval` in CSP — required for WebAssembly compilation
- `connect-src 'self' https:` — allows fetch to CORS proxies
- `<link rel="preload" ... as="fetch">` — starts downloading WASM while CSS loads
- `type="module"` on script — enables ES module `import`
- `#load-progress-bar` and `#load-progress-text` — IDs the JS loader updates

The `<div id="app">` is where LINKER mounts the application DOM. The loading content inside is replaced once the app starts.

---

## The CSS

All styles go in `styles.css`. LINKER renders DOM elements with CSS classes — there is no CSS-in-JS or scoped styles. Your CSS file is entirely your own.

For the loading screen, you need at minimum:

```css
.loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
}

.loading-progress {
    width: 240px;
    height: 4px;
    background: #e0e0e0;
    border-radius: 2px;
    overflow: hidden;
    margin-top: 8px;
}

.loading-progress__bar {
    height: 100%;
    background: #2196f3;
    border-radius: 2px;
    width: 0%;
    transition: width 0.3s ease;
}

.loading-progress__text {
    font-size: 12px;
    color: #999;
    font-variant-numeric: tabular-nums;
}
```

---

## Local Development Server

WASM files need the correct MIME type (`application/wasm`) and optional COOP/COEP headers for WebGPU:

```bash
python3 -c "
import http.server, socketserver

class H(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        '.wasm': 'application/wasm'
    }
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()

socketserver.TCPServer(('', 8080), H).serve_forever()
"
```

Run from the directory containing `index.html`, then open `http://localhost:8080`.

The COOP/COEP headers are required for:
- `SharedArrayBuffer` (used by WASM threading)
- WebGPU (requires cross-origin isolation in some browsers)

---

## Deploying to GitHub Pages

### Branch structure

- `main` — source code, Dockerfile, patches
- `gh-pages` — deployed static files (flat, no subdirectories)

### gh-pages contents

```
gh-pages branch root/
├── index.html
├── styles.css
├── BulletinBoard.js
├── BulletinBoard.wasm
└── sw.js              (optional service worker)
```

### Deploy steps

```bash
# 1. Build WASM (from parent directory)
docker build -f Dockerfile.bulletin-board -t my-app-wasm .
docker cp $(docker create my-app-wasm):/output/BulletinBoard.wasm Bulletin-Board/Public/

# 2. Copy assets to gh-pages
cd Bulletin-Board
git checkout gh-pages
cp Public/index.html .
cp Public/styles.css .
cp Public/BulletinBoard.js .
cp Public/BulletinBoard.wasm .

# 3. Commit and push
git add index.html styles.css BulletinBoard.js BulletinBoard.wasm
git commit -m "deploy"
git push origin gh-pages

# 4. Return to main
git checkout main
```

### GitHub Pages configuration

In your repo Settings → Pages:
- Source: **Deploy from a branch**
- Branch: **gh-pages** / **/ (root)**

The site will be available at `https://<username>.github.io/<repo-name>/`.

---

## Creating a New LINKER Project from Scratch

Step-by-step to create a new LINKER-based WASM web app:

### 1. Create the directory structure

```bash
mkdir -p parent/MyApp/Sources/MyApp
mkdir -p parent/MyApp/Public
mkdir -p parent/MyApp/patches
# LINKER must already exist at parent/LINKER/
```

### 2. Create Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .executable(name: "MyApp", targets: ["MyApp"])
    ],
    dependencies: [
        .package(path: "../LINKER"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.46.0")
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                .product(name: "LINKER", package: "LINKER"),
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit")
            ]
        )
    ]
)
```

### 3. Create main.swift

```swift
import Foundation
import LINKER

#if canImport(JavaScriptKit) && arch(wasm32)
import JavaScriptKit
import JavaScriptEventLoop

JavaScriptEventLoop.installGlobalExecutor()

Task {
    await App.main()
}

#else
print("MyApp - Native mode")
#endif
```

### 4. Create App.swift

```swift
import LINKER

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

struct App {
    static func main() async {
        #if arch(wasm32)
        let dom = DOMBridge()
        guard let root = dom.getElementById("app") else { return }
        root.innerHTML = "<h1>Hello from Swift WASM!</h1>"
        #endif
    }
}
```

### 5. Copy the patch file

Copy `patches/JavaScriptEventLoop+ExecutorFactory.swift` from Bulletin Board (full contents in [Patch 1](#patch-1-executorfactory-remove-available) above).

### 6. Copy the JavaScript loader

Copy `BulletinBoard.js` from Bulletin Board and rename references:
- Change `fetch('BulletinBoard.wasm')` to `fetch('MyApp.wasm')`
- The rest is app-agnostic

### 7. Create index.html

Use the template from [The HTML Shell](#the-html-shell) above.

### 8. Create styles.css

Add at minimum the loading styles from [The CSS](#the-css) above, plus your app styles.

### 9. Create .dockerignore

```
.swiftpm
.build
Bundle
dist
*.md
.git
.github
.DS_Store
```

### 10. Create Dockerfile

Copy `Dockerfile.bulletin-board` from the parent directory. Change:
- `COPY Bulletin-Board /workspace/Bulletin-Board` → `COPY MyApp /workspace/MyApp`
- `WORKDIR /workspace/Bulletin-Board` → `WORKDIR /workspace/MyApp`
- The `find .build -name "BulletinBoard.wasm"` → `find .build -name "MyApp.wasm"`
- Output filename as needed

### 11. Build and run

```bash
cd parent
docker build -f Dockerfile.myapp -t myapp-wasm .
docker cp $(docker create myapp-wasm):/output/MyApp.wasm MyApp/Public/MyApp.wasm

cd MyApp/Public
python3 -m http.server 8080
# Open http://localhost:8080
```

---

## Troubleshooting

### Task bodies never execute

**Symptom**: `Task { ... }` code never runs. No errors, just silent.

**Cause**: Executor not installed. Either:
- Patch 1 not applied (ExecutorFactory conformances invisible due to `@available`)
- Patch 2 not applied (`if #available(macOS 9999)` guard blocks `_createExecutors`)

**Fix**: Verify both patches are applied. Check Docker build output for "Patched ExecutorFactory" and "Patched JavaScriptEventLoop.swift" messages.

### "Expected XML string in response body"

**Symptom**: Feed fetching fails with parse error.

**Cause**: CORS proxy returned empty body or the proxy is dead.

**Fix**: Check that your CORS proxy URLs are working. `api.allorigins.win/raw?url=` is currently the most reliable free option.

### WASM binary not loading

**Symptom**: Browser shows "Failed to Load" or no progress.

**Cause**: Incorrect MIME type for `.wasm` file.

**Fix**: Ensure your web server returns `Content-Type: application/wasm`. Python's built-in HTTP server needs the custom handler shown in [Local Development Server](#local-development-server).

### WebGPU canvases show 300x150 default size

**Symptom**: GPU-rendered elements appear as small rectangles.

**Cause**: Canvas initialized before browser layout completes. `getBoundingClientRect()` returns 0 during synchronous `onMount`.

**Fix**: Wrap canvas initialization in double `requestAnimationFrame` (rAF inside rAF) to ensure layout is complete.

### Swift compiler version mismatch

**Symptom**: Build fails with obscure type errors or missing symbols.

**Cause**: Host Swift compiler version doesn't match WASM SDK version. March 1 SDK = 6.3, March 9 SDK = 6.4.

**Fix**: Ensure the Docker image tag matches. `nightly-main-jammy` is a floating tag — pin the digest for reproducibility.

### `fd_write` crashes or prints garbage

**Symptom**: `print()` statements crash or output corrupted text.

**Cause**: The `nwritten` parameter must be set to the **byte count** written, not the JavaScript string length. UTF-8 multi-byte characters make these different.

**Fix**: Sum `bufLen` values from the iovec array, not the decoded string length.

### Binary too large

**Symptom**: WASM file is >10MB (Foundation-free) or >60MB (with Foundation).

**Cause**: Missing optimization flags, `wasm-opt` not run, or `import Foundation` still present.

**Fix**: Ensure all of `-O`, `--gc-sections`, `--strip-all` are passed to the build, and `wasm-opt -Oz` with `--converge --vacuum --remove-unused-module-elements` runs post-build. Remove all `import Foundation` from source files — Foundation alone adds ~40MB to the binary. Expect ~7MB for a Foundation-free LINKER app.

### Swift 6.4-dev CopyPropagation SIL crash

**Symptom**: Compiler crashes during the WASM build with:
```
While running pass #NNNNN SILFunctionTransform "CopyPropagation" on SILFunction "..."
```

**Cause**: The Swift 6.4-dev compiler has a known bug in the `CopyPropagation` SIL pass that crashes when optimizing certain closure patterns targeting WASM. The following patterns trigger the crash:

- `array.compactMap { $0.stringValue }` — optional property access in compactMap
- `optional.map { Int($0) }` — type conversion in map closure
- `array.compactMap { SomeType(json: $0) }` — failable initializer in compactMap
- `ids.compactMap { dictionary[$0] }` — dictionary lookup in compactMap
- `optional.flatMap { SomeType(json: $0) }` — failable initializer in flatMap

**Fix**: Rewrite all such closures as explicit `for` loops:

```swift
// BAD — triggers compiler crash
let articles = array.compactMap { Article(json: $0) }
let count = json["count"]?.doubleValue.map { Int($0) } ?? 0
let items = ids.compactMap { byId[$0] }

// GOOD — explicit for-loops
var articles: [Article] = []
for item in array {
    if let article = Article(json: item) {
        articles.append(article)
    }
}

let count: Int
if let d = json["count"]?.doubleValue {
    count = Int(d)
} else {
    count = 0
}

var items: [Item] = []
for id in ids {
    if let item = byId[id] {
        items.append(item)
    }
}
```

> **Note on `-O` vs `-Osize`**: We use `-O` (speed) instead of `-Osize` (size) because
> `-Osize` triggers the CopyPropagation crash more aggressively. Both produce similar binary
> sizes after `wasm-opt -Oz` post-processing.

### `@dynamicMemberLookup` differences on WASM

**Symptom**: Code compiles on macOS but fails on WASM with force-unwrap errors, or vice versa.

**Cause**: JSObject/JSValue dynamic member lookup behaves differently on WASM SDK vs native:
- Direct method call: `obj.method!(args)` — `!` required
- Chained property access: `global?.WebAssembly.compile(args)` — no `!`

**Fix**: Use `#if arch(wasm32)` for WASM-specific interop code. Test with `!` on single-level calls, without `!` on multi-level chains.
