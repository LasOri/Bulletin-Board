# Modern WASM Build with Docker

This project uses **Docker with official Swift 6.2.4 Linux image** to build WASM bundles. This is the modern, official approach that works reliably on macOS.

## Why Docker?

On macOS, Apple's Swift doesn't support WASM cross-compilation. The official Swift WASM SDK requires a Linux Swift toolchain. Docker provides this environment without needing to set up complex toolchains locally.

## Prerequisites

- **Docker Desktop** - Install from https://www.docker.com/products/docker-desktop
- **Git** - For deployment

## Quick Deploy

```bash
./deploy.sh
```

This script:
1. ✅ Runs tests (native Swift)
2. 🐳 Builds WASM in Docker (Linux Swift 6.2.4 + WASM SDK)
3. 📦 Prepares distribution files
4. 🌐 Commits to `gh-pages` branch
5. 📋 Shows push instructions

## Manual Docker Build

To just build the WASM binary without deployment:

```bash
./build-docker.sh
```

Output: `Bundle/BulletinBoard.wasm`

## How It Works

### Dockerfile
- Uses official `swift:6.2.4` Linux image
- Installs Swift WASM SDK (swift-6.2.4-RELEASE_wasm)
- Builds project: `swift build --swift-sdk swift-6.2.4-RELEASE_wasm -c release`
- Extracts WASM binary to `/output/`

### Build Process
1. Docker builds image with all dependencies
2. Swift compiles to WASM inside Linux container
3. Script extracts WASM binary from container
4. Public assets (HTML, CSS, JS) are copied to Bundle/
5. Everything is ready for deployment

## Deployment Workflow

```bash
# Build and prepare
./deploy.sh

# Push to GitHub
git push origin gh-pages

# Configure GitHub Pages (first time only)
# Go to repo settings > Pages
# Source: Deploy from branch
# Branch: gh-pages / (root)
```

Your site will be live at: `https://lasori.github.io/Bulletin-Board/`

## Development

### Local Testing (Native Swift)
```bash
swift test  # Run all 398 tests
```

### WASM Development Server
For local WASM testing with hot-reload, you'll need to build your own dev server or use the Docker build + static file server.

## Technical Details

- **Swift Version**: 6.2.4 (official Linux image)
- **WASM SDK**: swift-6.2.4-RELEASE_wasm
- **Target**: wasm32-unknown-wasip1
- **Build Tool**: Official Swift Package Manager
- **No Carton**: Uses modern Swift SDK approach
- **Container**: Builds are isolated, reproducible

## Troubleshooting

### Docker not running
```bash
open -a Docker
```

Wait for Docker Desktop to start, then try again.

### Build fails
```bash
# Clean and rebuild
docker rmi bulletin-board-wasm
./deploy.sh
```

### Check build logs
```bash
docker build -t bulletin-board-wasm . --progress=plain
```
