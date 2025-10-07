// swift-tools-version: 5.9
// Simple Package configuration for the SwiftProxy demo app

import PackageDescription

let package = Package(
    name: "SimpleSwiftProxy",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SimpleSwiftProxy",
            targets: ["SimpleSwiftProxy"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SimpleSwiftProxy",
            path: "SwiftProxy",
            sources: [
                "SimpleSwiftProxyApp.swift"
            ],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)