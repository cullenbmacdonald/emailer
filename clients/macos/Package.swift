// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Emailer",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(path: "../shared")
    ],
    targets: [
        // Library target containing all views, view models, and logic.
        // Excludes the @main entry point so it can be tested without
        // conflicting with the test runner's _main symbol.
        .target(
            name: "EmailerLib",
            dependencies: [
                .product(name: "EmailClientKit", package: "shared")
            ],
            path: "Sources/Emailer",
            exclude: ["EmailApp.swift"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Executable target for the actual macOS app.
        // Includes only the @main entry point, depends on EmailerLib.
        .executableTarget(
            name: "Emailer",
            dependencies: ["EmailerLib"],
            path: "Sources/EmailerApp",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "EmailerTests",
            dependencies: ["EmailerLib"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
