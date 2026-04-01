# Bulletin Board - Swift WASM News Feed Reader

## Project Type
Swift WASM web application built with LINKER framework (signal-based reactive UI).
Compiles to WebAssembly, runs in browser via JavaScriptKit.

## Architecture
- 51 Swift source files, ~11,000 LOC
- LINKER framework for signals, Redux store, HTML DSL, DOMReconciler
- 5 actors: FeedService, StorageService, SearchService, NLPService, TFIDFEngine
- 1 class: CardExpansionController (@unchecked Sendable)
- Redux pattern: AppState -> appReducer -> Store<AppState>
- Components: struct-based with static render methods returning [AnyNode]

## Dual-Target Compilation
- **Native (macOS)**: `swift test` for XCTest -- no WASM, no JS interop
- **WASM (Docker)**: Cross-compilation with Swift 6.4-dev + WASM SDK
- Guards: `#if canImport(JavaScriptKit) && arch(wasm32)` for JS interop code
- Package.swift uses `WASM_BUILD=1` env var for JavaScriptEventLoop dependency

## LINKER Patterns (MUST follow)
- `SafeJSGlobal.global?` instead of `JSObject.global` (prevents SIGABRT in native tests)
- `AnySignal<T>` (concrete type) for Store.select() return types, NOT `any Signal<T>`
- `try? obj.throwing.method?(args)` for safe JS calls (never force-unwrap `!()`)
- `#if canImport(JavaScriptKit) && arch(wasm32)` for all JS interop (both conditions required)
- `nonisolated(unsafe)` for shared mutable state across concurrency boundaries
- No Foundation imports (already clean)
- No comments in code (absolute rule)

## Key Files
- Sources/BulletinBoard/main.swift -- Entry point
- Sources/BulletinBoard/State/Store.swift -- Redux store + selectors
- Sources/BulletinBoard/Components/App.swift -- Root component (~2500 LOC)
- Sources/BulletinBoard/Services/FeedService.swift -- RSS feed fetching
- Sources/BulletinBoard/Services/StorageService.swift -- IndexedDB persistence
- Package.swift -- Conditional WASM dependencies

## Current Issues (What This Feature Fixes)
1. Store.swift has 4 `any Signal<T>` existential returns that should be `AnySignal<T>`
2. App.swift:881 uses raw `JSObject.global` instead of `SafeJSGlobal.global?`
3. Consistency audit needed across all 51 files for LINKER pattern compliance

## Rules
- NO comments in code (no doc comments, no inline comments, no MARK sections)
- NO CSS fallbacks for GPU effects (WebGPU mandatory)
- Puppeteer tests required after WASM build
- Keep actors/async/await as-is (not converting to Embedded Swift)
