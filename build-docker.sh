#!/bin/bash
set -e

echo "🐳 Building Bulletin Board WASM using Docker"
echo "=============================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Build Docker image
echo -e "${BLUE}📦 Step 1: Building Docker image with Swift WASM SDK...${NC}"
docker build -t bulletin-board-wasm .

echo ""
echo -e "${GREEN}✅ Docker image built${NC}"
echo ""

# Extract WASM binary
echo -e "${BLUE}📤 Step 2: Extracting WASM binary from container...${NC}"
CONTAINER_ID=$(docker create bulletin-board-wasm)
docker cp "$CONTAINER_ID:/output/BulletinBoard.wasm" ./Bundle/BulletinBoard.wasm 2>/dev/null || mkdir -p Bundle && docker cp "$CONTAINER_ID:/output/BulletinBoard.wasm" ./Bundle/
docker rm "$CONTAINER_ID" >/dev/null

echo -e "${GREEN}✅ WASM binary extracted to Bundle/BulletinBoard.wasm${NC}"
echo "   Size: $(du -h Bundle/BulletinBoard.wasm | cut -f1)"
echo ""

# Copy public assets
if [ -d "Public" ]; then
    echo -e "${BLUE}📋 Step 3: Copying public assets...${NC}"
    cp Public/* Bundle/ 2>/dev/null || true
    echo -e "${GREEN}✅ Assets copied${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Build complete!${NC}"
echo ""
echo "Bundle contents:"
ls -lh Bundle/
