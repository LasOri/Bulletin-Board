# Local Build & Deploy Guide

This project uses **local builds** instead of GitHub Actions to save CI/CD minutes.

## Prerequisites

### Required
- Swift 6.2+ (for running tests)
- **Carton** - Swift WASM build tool
- Git configured with push access to the repository

### Install Carton (one-time setup)
```bash
brew install swiftwasm/tap/carton
```

Verify installation:
```bash
carton --version
```

## Quick Deploy

```bash
./deploy.sh
```

This script will:
1. ✅ Run all tests
2. 🔨 Build WASM binary using native Swift 6.2 SDK
3. 📦 Prepare distribution files
4. 🌐 Commit to `gh-pages` branch
5. 📋 Show push instructions

## Manual Steps After First Deploy

### 1. Push to GitHub
```bash
git push origin gh-pages
```

### 2. Configure GitHub Pages (one-time setup)
1. Go to: https://github.com/LasOri/Bulletin-Board/settings/pages
2. **Source**: Deploy from a branch
3. **Branch**: `gh-pages` / `(root)`
4. Click **Save**

### 3. Access Your Site
After GitHub Pages builds (takes 1-2 minutes), visit:
```
https://lasori.github.io/Bulletin-Board/
```

## Build Details

### Carton WASM Build
Uses Carton CLI for reliable WASM builds:
```bash
carton bundle --release
```

### Why Carton?
- Handles all WASM toolchain complexity
- Bundles WASM + JavaScript loader
- Most reliable Swift WASM build tool
- Used by the Swift WASM community

### Output Location
- Carton bundle: `Bundle/` directory containing:
  - `BulletinBoard.wasm` - Compiled Swift code
  - `BulletinBoard.js` - JavaScript loader/runtime
  - `index.html` - Default HTML (can be overridden)
- Distribution: `dist/` (staged for gh-pages)

## Development Workflow

```bash
# Run tests locally
swift test

# Build and deploy
./deploy.sh

# Push to GitHub
git push origin gh-pages
```

## No GitHub Actions
This project intentionally **does not use GitHub Actions** to preserve free tier minutes. All builds happen locally on your machine.

## Troubleshooting

### Carton Not Found
```bash
# Install Carton
brew install swiftwasm/tap/carton

# Verify
carton --version
```

### Build Fails
```bash
# Clean build
rm -rf .build Bundle
./deploy.sh
```

### Push Rejected
```bash
# Force push (use with caution)
git push origin gh-pages --force
```

## Development Workflow

### Local Development Server
```bash
# Run development server with hot reload
carton dev

# Opens browser to http://localhost:8080
# Changes auto-reload
```

### Test Changes
```bash
# Run tests only
swift test

# Test in browser
carton dev
```
