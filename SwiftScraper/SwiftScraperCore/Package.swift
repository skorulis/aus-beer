// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftScraperCore",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(name: "SwiftScraperCore", targets: ["SwiftScraperCore"]),
    ],
    targets: [
        .target(name: "SwiftScraperCore"),
        .testTarget(
            name: "SwiftScraperCoreTests",
            dependencies: ["SwiftScraperCore"],
            exclude: ["fixtures"]
        ),
    ]
)
