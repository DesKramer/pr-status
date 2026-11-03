// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PRStatus",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PRStatus", targets: ["PRStatus"])
    ],
    targets: [
        .executableTarget(name: "PRStatus"),
        .testTarget(name: "PRStatusTests", dependencies: ["PRStatus"])
    ]
)
