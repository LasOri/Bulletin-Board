# Bulletin Board

A modern RSS/Atom feed reader built with Swift compiled to WebAssembly via the [LINKER](https://github.com/nicktmro/LINKER) reactive UI framework. Runs entirely in the browser with zero backend — all processing (NLP, storage, rendering) happens client-side.

**Live Demo**: [lasori.github.io/Bulletin-Board](https://lasori.github.io/Bulletin-Board/)

## Features

- **Multi-feed RSS/Atom reader** with auto-discovery and CORS proxy fallback chain
- **Local NLP** — TextRank summarization, TF-IDF keyword extraction, auto-categorization, K-means topic clustering
- **WebGPU effects** — hardware-accelerated shadows and blur via WGSL shaders on `<canvas>` elements
- **Full-text search** with ranked results and match-field badges
- **Offline-first** — IndexedDB storage with WebAuthn-backed encryption fallback
- **Virtual scrolling** for 1000+ articles
- **Dark mode** with system preference detection
- **Mobile responsive** with touch-optimized controls (44px targets)
- **Privacy-focused** — no analytics, no tracking, no server

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 6.4-dev |
| Framework | [LINKER](https://github.com/nicktmro/LINKER) (signal-based reactive UI) |
| Runtime | Swift WASM + JavaScriptKit 0.46.5 (patched) |
| Build | Docker (`swiftlang/swift:nightly-main-jammy`) |
| GPU | WebGPU + WGSL shaders |
| State | Redux architecture (Store/Reducer/Middleware) |
| Storage | IndexedDB |
| Deployment | GitHub Pages (gh-pages branch) |

## Quick Start

### Prerequisites

- Docker
- Parent directory must contain the [LINKER](https://github.com/nicktmro/LINKER) framework:
  ```
  parent/
  ├── LINKER/
  └── Bulletin-Board/
  ```

### Build

```bash
cd ..
docker build -f Dockerfile.bulletin-board -t bulletin-board-wasm .
docker cp $(docker create bulletin-board-wasm):/output/BulletinBoard.wasm Bulletin-Board/Public/
```

### Run Locally

```bash
cd Bulletin-Board
python3 -c "
import http.server, socketserver

class H(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm'}
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()

socketserver.TCPServer(('', 8080), H).serve_forever()
" &
open http://localhost:8080/Public/index.html
```

### Run Tests

```bash
swift test
swift test --filter ArticleTests
```

## Project Structure

```
Sources/BulletinBoard/
├── main.swift                    Entry point (WASM-guarded)
├── Components/
│   ├── App.swift                 Root component, proxy config, mount logic
│   ├── ArticleCard.swift         Feed card with hero image
│   ├── ArticleDetailView.swift   Expanded article view
│   ├── ArticleList.swift         Virtual-scrolled article list
│   ├── CategoryGrid.swift        Category-grouped view
│   ├── FeedManager.swift         Add/remove/discover feeds
│   ├── SearchBar.swift           Full-text search with ranked results
│   └── GPU/                      WebGPU canvas lifecycle
├── Models/
│   ├── Article.swift
│   ├── Feed.swift
│   ├── DiscoveredFeed.swift
│   └── FeedPreview.swift
├── Services/
│   ├── FeedService.swift         RSS fetch with CORS proxy fallback
│   ├── SearchService.swift       TF-IDF indexed full-text search
│   ├── StorageService.swift      IndexedDB with encryption fallback
│   ├── OPMLService.swift         OPML import/export
│   └── NLP/                      TextRank, TF-IDF, K-means
├── State/
│   ├── Store.swift               Redux store
│   ├── AppState.swift            Root state
│   ├── AppReducer.swift          Root reducer
│   ├── Articles/                 Article actions/reducers
│   ├── Feeds/                    Feed actions/reducers
│   └── UI/                       UI state actions/reducers
└── Security/
    └── CSPConfiguration.swift    Content Security Policy

patches/
└── JavaScriptEventLoop+ExecutorFactory.swift   WASM executor fix

Public/
├── index.html                    App shell with loading progress
├── styles.css                    All styles (dark mode, responsive)
├── BulletinBoard.js              WASM loader with download progress
└── BulletinBoard.wasm            Compiled binary (~48MB)
```

## CORS Proxy

Browser CORS restrictions prevent direct RSS fetching. The app uses a proxy fallback chain:

1. `api.allorigins.win/raw` (primary)
2. `api.codetabs.com/v1/proxy` (fallback)

If all proxies fail, the error is surfaced to the user. No registration or API keys required.

## Deployment

The app deploys to GitHub Pages via the `gh-pages` branch.

```bash
git checkout gh-pages
cp Public/index.html Public/styles.css Public/BulletinBoard.js Public/BulletinBoard.wasm .
git add -A && git commit -m "deploy" && git push
git checkout main
```

## JavaScriptKit Patches

JavaScriptKit 0.46.5 requires two patches for WASM compatibility:

1. **ExecutorFactory** (`patches/`): Removes `@available` annotations that fail on WASM (no OS versioning)
2. **installGlobalExecutor** (Dockerfile `sed`): Removes `if #available(macOS 9999, ...)` guard that prevents executor installation on WASM, causing `Task {}` bodies to never run

## License

MIT License — see [LICENSE](./LICENSE) for details.
