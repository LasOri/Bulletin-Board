# Use official Swift image (Linux)
FROM swift:6.2.4

# Install Swift WASM SDK
RUN swift sdk install \
    https://download.swift.org/swift-6.2.4-release/wasm-sdk/swift-6.2.4-RELEASE/swift-6.2.4-RELEASE_wasm.artifactbundle.tar.gz \
    --checksum 32fdb8772d73bb174f77b5c59bc88a0d55003d75712832129394d3465158fb43

# Verify SDK installation
RUN swift sdk list

# Set working directory
WORKDIR /workspace

# Copy LINKER framework (local dependency)
COPY ../LINKER /linker

# Copy Bulletin Board project
COPY . .

# Build WASM binary
RUN swift build --swift-sdk swift-6.2.4-RELEASE_wasm --configuration release

# Create output directory and copy WASM binary
RUN mkdir -p /output && \
    cp .build/swift-6.2.4-RELEASE_wasm/wasm32-unknown-wasip1/release/BulletinBoard.wasm /output/

# Default command
CMD ["swift", "build", "--swift-sdk", "swift-6.2.4-RELEASE_wasm", "--configuration", "release"]
