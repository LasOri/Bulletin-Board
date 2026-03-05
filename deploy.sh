#!/bin/bash
set -e  # Exit on error

echo "🚀 Bulletin Board - Docker WASM Build & Deploy to GitHub Pages"
echo "================================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REPO_DIR=$(pwd)
BUNDLE_DIR="$REPO_DIR/Bundle"
DIST_DIR="$REPO_DIR/dist"
PUBLIC_DIR="$REPO_DIR/Public"
GH_PAGES_BRANCH="gh-pages"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found!${NC}"
    echo "Docker is required to build Swift WASM on macOS."
    echo "Install from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

echo -e "${BLUE}✓ Using Docker: $(docker --version)${NC}"
echo ""

# Step 1: Run tests
echo -e "${BLUE}📋 Step 1/5: Running tests...${NC}"
swift test
echo -e "${GREEN}✅ All tests passed${NC}"
echo ""

# Step 2: Build WASM bundle
echo -e "${BLUE}🔨 Step 2/5: Building WASM binary with Docker...${NC}"

# Clean previous build
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Build with Docker
docker build -t bulletin-board-wasm .

# Extract WASM binary from container
CONTAINER_ID=$(docker create bulletin-board-wasm)
docker cp "$CONTAINER_ID:/output/BulletinBoard.wasm" "$BUNDLE_DIR/"
docker rm "$CONTAINER_ID" >/dev/null

if [ ! -f "$BUNDLE_DIR/BulletinBoard.wasm" ]; then
    echo -e "${RED}❌ WASM binary not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ WASM binary built successfully${NC}"
echo "   Size: $(du -h "$BUNDLE_DIR/BulletinBoard.wasm" | cut -f1)"
echo ""

# Step 3: Prepare distribution directory
echo -e "${BLUE}📦 Step 3/5: Preparing distribution files...${NC}"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Copy Carton bundle output
cp -r "$BUNDLE_DIR/"* "$DIST_DIR/"
echo "   ✓ Copied Carton bundle (WASM + JS loader)"

# Overlay custom public assets (if any)
if [ -d "$PUBLIC_DIR" ]; then
    # Copy custom files, overwriting Carton's defaults
    if [ -f "$PUBLIC_DIR/index.html" ]; then
        cp "$PUBLIC_DIR/index.html" "$DIST_DIR/"
        echo "   ✓ Using custom index.html"
    fi
    if [ -f "$PUBLIC_DIR/styles.css" ]; then
        cp "$PUBLIC_DIR/styles.css" "$DIST_DIR/"
        echo "   ✓ Using custom styles.css"
    fi
    if [ -f "$PUBLIC_DIR/BulletinBoard.js" ]; then
        cp "$PUBLIC_DIR/BulletinBoard.js" "$DIST_DIR/"
        echo "   ✓ Using custom BulletinBoard.js"
    fi
fi

# Create .nojekyll to prevent GitHub Pages from processing files
touch "$DIST_DIR/.nojekyll"
echo "   ✓ Created .nojekyll"

echo -e "${GREEN}✅ Distribution prepared${NC}"
echo ""
echo "📊 Distribution contents:"
ls -lh "$DIST_DIR/"
echo ""

# Step 4: Deploy to gh-pages branch
echo -e "${BLUE}🌐 Step 4/5: Deploying to gh-pages branch...${NC}"

# Check if gh-pages branch exists
if git show-ref --verify --quiet refs/heads/$GH_PAGES_BRANCH; then
    echo "   ✓ gh-pages branch exists"
else
    echo "   ⚠ Creating gh-pages branch..."
    git branch $GH_PAGES_BRANCH
fi

# Save current branch
CURRENT_BRANCH=$(git branch --show-current)

# Commit dist to gh-pages
git checkout $GH_PAGES_BRANCH

# Remove old files (keep .git)
find . -maxdepth 1 ! -name '.git' ! -name '.' ! -name '..' -exec rm -rf {} +

# Copy new files
cp -r "$DIST_DIR/"* .

# Commit
git add -A
if git diff --staged --quiet; then
    echo -e "${BLUE}ℹ️  No changes to deploy${NC}"
else
    COMMIT_MSG="Deploy: $(date '+%Y-%m-%d %H:%M:%S')"
    git commit -m "$COMMIT_MSG"
    echo -e "${GREEN}✅ Changes committed${NC}"
fi

# Return to original branch
git checkout $CURRENT_BRANCH

echo -e "${GREEN}✅ Deployment prepared${NC}"
echo ""

# Step 5: Push to GitHub
echo -e "${BLUE}🚀 Step 5/5: Pushing to GitHub...${NC}"
echo ""
echo "Ready to push gh-pages branch to GitHub!"
echo ""
echo "Run one of these commands:"
echo "  ${GREEN}git push origin gh-pages${NC}              # Push gh-pages branch"
echo "  ${GREEN}git push origin gh-pages --force${NC}      # Force push (if needed)"
echo ""
echo "After pushing, configure GitHub Pages:"
echo "  1. Go to: https://github.com/LasOri/Bulletin-Board/settings/pages"
echo "  2. Source: Deploy from a branch"
echo "  3. Branch: gh-pages / (root)"
echo "  4. Save"
echo ""
echo "Your site will be live at:"
echo "  ${BLUE}https://lasori.github.io/Bulletin-Board/${NC}"
echo ""
echo -e "${GREEN}🎉 Build complete!${NC}"
