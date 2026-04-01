# Lessons: project

## Lesson 1: SafeJSGlobal wrapper required
- **Category**: pattern
- **Description**: Always use SafeJSGlobal.global? instead of JSObject.global. The latter causes SIGABRT when accessed in native test builds. SafeJSGlobal returns nil safely in non-WASM environments.

## Lesson 2: AnySignal not any Signal
- **Category**: correction
- **Description**: Store.select() returns AnySignal<T> (concrete struct), not any Signal<T> (existential). Using the existential type causes unnecessary boxing overhead. The LINKER Store API returns AnySignal<T> directly.

## Lesson 3: Dual guard required for JS imports
- **Category**: pattern
- **Description**: Use #if canImport(JavaScriptKit) && arch(wasm32) for all JS interop code. Using canImport alone is insufficient because JavaScriptKit resolves as importable during native swift test builds. The arch(wasm32) check ensures the code only compiles when targeting WebAssembly.

## Lesson 4: No comments in any code
- **Category**: preference
- **Description**: Absolutely no comments in code. No doc comments, no inline comments, no MARK sections. Strip all comments when touching a file.

## Lesson 5: Safe JS call pattern
- **Category**: pattern
- **Description**: Use try? obj.throwing.method?(args) for JS calls. Never use obj.method!(args) which causes WASM unreachable traps on JS exceptions. The .throwing dynamic member lookup uses the catching variant of the WASM import.
