// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NotionKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NotionKit",
            targets: ["NotionKit"]),
        .library(
            name: "NotionKitVapor",
            targets: ["NotionKitVapor"]),
        .library(
            name: "NotionKitClient",
            targets: ["NotionKitClient"]),
    ],
    dependencies: [
        // Dependencies for server-side (Vapor)
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
        
        // Dependencies for both client and server
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0"),
    ],
    targets: [
        // Core target with shared models and utilities
        .target(
            name: "NotionKit",
            dependencies: []),
        
        // Server-side (Vapor) target
        .target(
            name: "NotionKitVapor",
            dependencies: [
                "NotionKit",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
            ]),
        
        // Client-side (SwiftUI) target
        .target(
            name: "NotionKitClient",
            dependencies: [
                "NotionKit",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        
        // Test targets
        .testTarget(
            name: "NotionKitTests",
            dependencies: ["NotionKit"]),
        .testTarget(
            name: "NotionKitVaporTests",
            dependencies: ["NotionKitVapor"]),
        .testTarget(
            name: "NotionKitClientTests",
            dependencies: ["NotionKitClient"]),
    ]
)
