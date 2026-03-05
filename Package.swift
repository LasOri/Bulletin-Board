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
        // Carton for WASM build plugins (modern SwiftPM plugin approach)
        .package(url: "https://github.com/swiftwasm/carton", from: "1.1.0")
    ],
    targets: [
        .executableTarget(
            name: "BulletinBoard",
            dependencies: [
                .product(name: "LINKER", package: "LINKER")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
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
