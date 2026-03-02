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
- [ ] Redux store (Phase 1)
- [ ] Feed management (Phase 1)
- [ ] Basic UI (Phase 1)
- [ ] NLP engine (Phase 2)
- [ ] Advanced animations (Phase 3)
- [ ] Search & filters (Phase 3)
- [ ] Polish & testing (Phase 4)

## License

MIT License - see [LICENSE](./LICENSE) for details

## Related Projects

- [LINKER Framework](../LINKER) - The reactive UI framework powering Bulletin Board
