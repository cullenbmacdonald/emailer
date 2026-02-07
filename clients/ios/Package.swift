// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "EmailerIOS",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    dependencies: [
        .package(path: "../shared")
    ],
    targets: [
        // Library target containing all views, view models, and logic.
        // Excludes the @main entry point so it can be tested without
        // conflicting with the test runner's _main symbol.
        .target(
            name: "EmailerIOSLib",
            dependencies: [
                .product(name: "EmailClientKit", package: "shared")
            ],
            path: "Sources/EmailerIOS",
            exclude: ["EmailApp_iOS.swift"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Executable target for the actual iOS app.
        // Includes only the @main entry point, depends on EmailerIOSLib.
        .executableTarget(
            name: "EmailerIOS",
            dependencies: ["EmailerIOSLib"],
            path: "Sources/EmailerIOSApp",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "EmailerIOSTests",
            dependencies: ["EmailerIOSLib"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
