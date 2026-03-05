#!/bin/bash
export PATH="/opt/homebrew/opt/llvm/bin:/opt/homebrew/opt/lld/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
cd "$(dirname "$0")"
swift build --swift-sdk swift-6.2.4-RELEASE_wasm --configuration release "$@"
