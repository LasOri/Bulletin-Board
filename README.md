# Bulletin Board

A modern, intelligent news feed reader built with LINKER framework, demonstrating Swift WASM capabilities, reactive UI patterns, and local NLP processing.

## Overview

Bulletin Board is a production-quality news feed reader that runs entirely in the browser using Swift compiled to WebAssembly. It features:

- 🗞️ **Multi-feed support** - Subscribe to unlimited RSS/Atom feeds
- 🤖 **Local NLP** - Text summarization, categorization, and clustering (client-side)
- ⚡ **High performance** - Virtual scrolling handles 1000+ articles smoothly
- 🎨 **Beautiful animations** - AppStore-style card expansion with spring physics
- 💾 **Offline-first** - IndexedDB storage for offline reading
- 🔒 **Privacy-focused** - Zero backend, all processing happens locally
- 🌙 **Dark mode** - Full dark theme support

## Tech Stack

- **Language**: Swift 6.2+
- **Framework**: [LINKER](../LINKER) (Signal-based reactive UI framework)
- **Runtime**: Swift WASM + JavaScriptKit
- **Build Tool**: Carton
- **State Management**: Redux architecture
- **Storage**: IndexedDB
- **Testing**: XCTest

## Quick Start

### Prerequisites

- Swift 6.2+ with WebAssembly support
- Carton (`brew install swiftwasm/tap/carton`)

### Development

```bash
# Install dependencies (LINKER framework is local)
cd /Users/I525390/Documents/own/Bulletin-Board

# Run development server
carton dev

# Open browser to http://127.0.0.1:8080
```

### Build for Production

```bash
# Build optimized WASM bundle
carton bundle

# Output in Bundle/BulletinBoard.wasm
```

### Testing

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter ArticleTests
```

## Project Structure

```
Sources/BulletinBoard/
├── BulletinBoard.swift          # Entry point
├── App.swift                     # Root component
├── State/                        # Redux store
├── Components/                   # UI components
├── Services/                     # Business logic
├── NLP/                         # NLP algorithms
├── Models/                      # Data models
├── Animations/                  # Custom animations
└── Utils/                       # Utilities

Tests/BulletinBoardTests/
├── StateTests/
├── ComponentTests/
├── ServiceTests/
└── NLPTests/
```

## Features

### Feed Management
- Subscribe to RSS/Atom feeds
- Auto-discovery from URLs
- Feed organization
- Offline caching
- Manual/auto refresh

### Content Analysis (Local NLP)
- Text summarization (TextRank)
- Keyword extraction (TF-IDF)
- Auto-categorization
- Topic clustering (K-means)
- All processing client-side

### UI/UX
- Virtual scrolling
- AppStore-style animations
- Backdrop blur effects
- Responsive design
- Dark mode

### Article Management
- Read/unread tracking
- Favorites
- Archive
- Full-text search
- Filter by category/feed/date

## Development Standards

See [BULLETIN_BOARD_PLAN.md](./Sources/BulletinBoard/BULLETIN_BOARD_PLAN.md) for:
- Code quality standards
- Testing requirements
- File organization
- Naming conventions
- Git commit standards
- Performance targets

## Roadmap

- [x] Project setup
- [x] Redux store (Phase 1) - ✅ 338 tests
- [x] GPU integration (Phase 2) - ✅ 42 tests
- [x] Security features (Phase 3) - ✅ 18 tests
- [x] UI implementation (Phase 4) - ✅ Complete
- [x] CI/CD pipeline (Phase 4) - ✅ GitHub Actions

**Current Status**: 🎉 **398 tests passing** - Ready for deployment!

## 🚀 Deployment

The app automatically deploys to GitHub Pages on every push to `main`.

**Live Demo**: https://lasori.github.io/Bulletin-Board/ _(will be live after first deployment)_

### CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/deploy.yml`) automatically:

1. ✅ Runs all 398 tests
2. ✅ Verifies security features (XSS, CSRF, rate limiting)
3. ✅ Builds optimized WASM bundle
4. ✅ Deploys to GitHub Pages

### Manual Deployment

If you want to deploy manually:

```bash
# Install Carton if not already installed
brew install swiftwasm/tap/carton

# Build production bundle
carton bundle --release

# The Bundle/ directory will contain:
# - BulletinBoard.wasm (compiled Swift code)
# - BulletinBoard.js (JavaScript loader)

# Copy to deployment directory
mkdir -p dist
cp -r Bundle/* dist/
cp Public/index.html dist/
cp Public/styles.css dist/

# Deploy dist/ to your web server
```

### Local Development Without Carton

If you don't have Carton installed, you can still develop and test:

```bash
# Run tests (native Swift, no WASM needed)
swift test

# All 398 tests will run in native Swift mode
# UI rendering tests are skipped in non-WASM environments
```

To test the UI in a browser, you need Carton:

```bash
# Install Carton
brew install swiftwasm/tap/carton

# Run development server with hot reload
carton dev

# Browser opens automatically to http://localhost:8080
```

## License

MIT License - see [LICENSE](./LICENSE) for details

## Related Projects

- [LINKER Framework](../LINKER) - The reactive UI framework powering Bulletin Board
