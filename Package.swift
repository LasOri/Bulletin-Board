// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BulletinBoard",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(
            name: "BulletinBoard",
            targets: ["BulletinBoard"]
        )
    ],
    dependencies: [
        // LINKER Framework - use local path
        .package(path: "../LINKER"),
        // JavaScriptKit for JS interop + JavaScriptEventLoop for async/await
        // Also provides PackageToJS plugin (verb: "js") for WASM builds
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.46.0")
    ],
    targets: [
        .executableTarget(
            name: "BulletinBoard",
            dependencies: [
                .product(name: "LINKER", package: "LINKER"),
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit")
            ]
        ),
        .testTarget(
            name: "BulletinBoardTests",
            dependencies: [
                "BulletinBoard",
                .product(name: "LINKER", package: "LINKER"),
                .product(name: "LINKERTesting", package: "LINKER")
            ]
        )
    ]
)
