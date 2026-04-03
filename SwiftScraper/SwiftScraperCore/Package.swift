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
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
    ],
    targets: [
        .target(
            name: "SwiftScraperCore",
            dependencies: [
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ]
        ),
        .testTarget(
            name: "SwiftScraperCoreTests",
            dependencies: ["SwiftScraperCore"],
            exclude: ["fixtures"]
        ),
    ]
)
