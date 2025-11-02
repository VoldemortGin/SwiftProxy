// swift-tools-version: 5.9
// Cross-platform Package configuration for SwiftProxy

import PackageDescription

let package = Package(
    name: "SwiftProxy",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        // Shared core library - can be used by all platforms
        .library(
            name: "SwiftProxyCore",
            targets: ["SwiftProxyCore"]
        ),
        // macOS executable app
        .executable(
            name: "SimpleSwiftProxy",
            targets: ["SimpleSwiftProxy"]
        )
    ],
    targets: [
        // MARK: - Shared Core Library (Cross-Platform)
        .target(
            name: "SwiftProxyCore",
            path: "Shared",
            sources: [
                "Core/",
                "Models/",
                "Services/",
                "Errors/"
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ]
        ),

        // MARK: - macOS Executable
        .executableTarget(
            name: "SimpleSwiftProxy",
            dependencies: ["SwiftProxyCore"],
            path: "Platform/macOS",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "SwiftProxyTests",
            dependencies: ["SwiftProxyCore"],
            path: "SwiftProxyTests"
        ),
        .testTarget(
            name: "SwiftProxyIntegrationTests",
            dependencies: ["SwiftProxyCore", "SimpleSwiftProxy"],
            path: "SwiftProxyIntegrationTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
