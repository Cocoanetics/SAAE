// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SAAE",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "SAAE",
            targets: ["SAAE"]),
        .executable(
            name: "SAAEDemo",
            targets: ["SAAEDemo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.7.0")
    ],
    targets: [
        .target(
            name: "SAAE",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftParserDiagnostics", package: "swift-syntax"),
                "Yams"
            ]),
        .executableTarget(
            name: "SAAEDemo",
            dependencies: [
                "SAAE",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .testTarget(
            name: "SAAETests",
            dependencies: [
                "SAAE",
                .product(name: "Testing", package: "swift-testing")
            ],
            resources: [
                .copy("Resources")
            ]),
    ]
) 
