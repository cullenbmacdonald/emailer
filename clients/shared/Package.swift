// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "EmailClientKit",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "EmailClientKit",
            targets: ["EmailClientKit"]
        )
    ],
    targets: [
        .target(
            name: "EmailClientKit",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "EmailClientKitTests",
            dependencies: ["EmailClientKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
